#!/bin/bash

# deployment config
config_server="user@host"                    # server to deploy to
config_port="22"                             # SSH port to use, defaults to 22
config_repo="git@github.com:user/repo.git"   # git repo to clone when creating a build
config_localcmd="npm install --production"   # local command run before deploy
config_remotecmd=""                          # remote command run after deploy
config_path="/var/www/app"                   # path on server to deploy to
config_systemd="deploy/app.service"          # relative location of systemd service file
config_nginx="deploy/app.conf"               # relative location of nginx config file
config_nginx_path="/etc/nginx/conf.d"        # server location of nginx config file

# internal build variables
base=$(pwd -P)
repo=$(git ls-remote "$config_repo" | grep refs/heads/master | cut -f1)

function cleanup {
	# remove all files generated during build
	rm -rf "$base/build"
}

function clean_repo {
	# remove files that should not be included in deploy
	cd "$base/build/$repo"
	rm -rf .git .gitignore
}

function check_error {
	# check if last command failed
	if [ $? -ne 0 ]; then
		# display error and exit if so
		echo "error: $1"
		cleanup
		exit 1
	fi
}

function create_build {
	# create temporary build directory and clone repo
	mkdir -p "$base/build"
	git clone --quiet "$config_repo" "$base/build/$repo"
	check_error "clone failed: $config_repo"

	# clean repo and run local command
	clean_repo
	eval "$config_localcmd" > /dev/null 2>&1
	check_error "local command failed: $config_localcmd"

	# archive build into tar.gz
	cd "$base/build"
	tar -zcf build.tar.gz "$repo"
}

function upload_build {
	# create required deployment paths on server if necessary
	ssh -p $config_port "$config_server" "mkdir -p $config_path && rm -rf $config_path/build.tar.gz"
	check_error "failed to initialise upload"

	# scp build package to server
	scp -P $config_port -q "$base/build/build.tar.gz" "$config_server:$config_path" > /dev/null 2>&1
	check_error "failed to upload build"
}

function deploy {
	local app_name=$(basename -s .service $config_systemd)
	local service_file=$(basename $config_systemd)
	local nginx_file=$(basename $config_nginx)

	# execute server-side deploy
	ssh -p $config_port "$config_server" "bash -s" <<-SCRIPT
		# stop app process
		systemctl stop "$service_file" > /dev/null 2>&1

		# report app stop status
		if [ \$? -eq 0 ]; then
			echo "info: $app_name stopped"
		else
			echo "warn: $app_name is not running on server"
		fi

		# remove duplicate in case of multiple deploys of same SHA
		rm -rf "$config_path/$repo"

		# extract build
		cd "$config_path"
		tar -mxzf build.tar.gz
		rm build.tar.gz

		# symlink latest build to current
		ln -sfn "$config_path/$repo" "$config_path/current"

		# remove everything except the current build
		shopt -s extglob
		rm -rf !("$repo"|current)

		# update systemd service file
		cp "$config_path/current/$config_systemd" "/etc/systemd/system/$service_file"

		# ensure service starts with system boot
		systemctl enable "$service_file" > /dev/null 2>&1

		if [ \$? -ne 0 ]; then
			echo "error: failed to enable service"
			exit 1
		fi

		# run remote command
		cd "$config_path/current"
		eval "$config_remotecmd" > /dev/null 2>&1

		if [ \$? -ne 0 ]; then
			echo "error: remote command failed: $config_remotecmd"
			exit 1
		fi

		# start service
		systemctl start "$service_file" > /dev/null 2>&1

		# wait 5s and check app is still alive
		sleep 5
		systemctl status "$service_file" > /dev/null 2>&1

		if [ \$? -eq 0 ]; then
			echo "info: $app_name started"
		else
			echo "error: $app_name failed to start"
			exit 1
		fi

		# update symlink to nginx config if required
		if [ ! -z "$config_nginx" ]; then
			ln -sfn "$config_path/current/$config_nginx" "$config_nginx_path/$nginx_file"

			# reload nginx config
			nginx -s reload > /dev/null 2>&1

			# report nginx config reload fail
			if [ \$? -ne 0 ]; then
				echo "error: nginx reload failed"
				exit 1
			fi
		fi
	SCRIPT
}

# set default config values
config_port=${config_port:-"22"}
config_nginx_path=${config_nginx_path:-"/etc/nginx/conf.d"}

echo "info: creating build $repo"
create_build

echo "info: pushing to server"
upload_build

echo "info: deploying"
deploy

cleanup
