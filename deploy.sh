#!/bin/bash

# deployment config
config_server="root@host"                    # server to deploy to
config_port="22"                             # SSH port to use, defaults to 22
config_repo="git@github.com:user/app.git"    # git repo to clone when creating a build
config_buildcmd="npm install --production"   # local build command
config_path="/var/www/app"                   # path on server to deploy to
config_upstart="deploy/app.conf"             # relative location of upstart config file
config_nginx="deploy/app"                    # relative location of nginx config file
config_nginx_path="/etc/nginx/sites-enabled" # server location of nginx config file

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
	rm -rf .git .gitignore .jshintrc
}

function check_error {
	# check if last command failed
	if [ $? -ne 0 ]; then
		# display error and exit if so
		echo "fail: $1"
		cleanup
		exit 1
	fi
}

function create_build {
	# create temporary build directory and clone repo
	mkdir -p "$base/build"
	git clone -q "$config_repo" "$base/build/$repo" > /dev/null 2>&1
	check_error "clone failed: $config_repo"

	# clean repo and run custom build command
	clean_repo
	eval "$config_buildcmd" > /dev/null 2>&1
	check_error "build cmd failed: $config_buildcmd"

	# archive build into tar.gz
	cd "$base/build"
	tar -zcf build.tar.gz "$repo"
}

function upload_build {
	# create required deployment paths on server if necessary
	ssh "$config_server" "mkdir -p $config_path && rm -rf $config_path/build.tar.gz"
	check_error "failed to initialise upload"

	# scp build package to server
	scp -q "$base/build/build.tar.gz" "$config_server:$config_path" > /dev/null 2>&1
	check_error "failed to upload build"
}

function deploy {
	# work out filenames for nginx and upstart configs
	local app_name=$(basename -s .conf $config_upstart)
	local nginx_config_name=$(basename $config_nginx)

	# execute server-side deploy
	ssh "$config_server" "bash -s" <<-SCRIPT
		# stop app process
		initctl stop "$app_name" > /dev/null 2>&1

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

		# remove inactive builds
		shopt -s extglob
		rm -rf !("$repo"|current)

		# update symlink to upstart config
		ln -sfn "$config_path/current/$config_upstart" "/etc/init/$app_name.conf"

		# reload upstart config to detect symlink
		initctl reload-configuration

		# start app process
		initctl start "$app_name" > /dev/null 2>&1

		# report new app status
		if [ \$? -eq 0 ]; then
			echo "info: $app_name started"
		else
			echo "fail: $app_name failed to start"
			exit 1
		fi

		# update symlink to nginx config if required
		if [ ! -z "$config_nginx" ]; then
			ln -sfn "$config_path/current/$config_nginx" "$config_nginx_path/$nginx_config_name"

			# reload nginx config
			nginx -s reload > /dev/null 2>&1

			# report nginx config reload fail
			if [ \$? -ne 0 ]; then
				echo "fail: nginx reload failed"
				exit 1
			fi
		fi
	SCRIPT
}

# set default config values
config_port=${config_port:-"22"}
config_nginx_path=${config_nginx_path:-"/etc/nginx/sites-enabled"}

echo "info: creating build $repo"
create_build

echo "info: pushing to server"
upload_build

echo "info: deploying"
deploy

cleanup