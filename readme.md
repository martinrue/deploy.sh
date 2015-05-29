# deploy.sh

`deploy.sh` is a simple bash script for creating local builds of a node app and deploying them to an nginx + upstart server via SSH.

## How to use
Simply copy the [deploy.sh](https://raw.githubusercontent.com/martinrue/deploy.sh/master/deploy.sh) script into your project and update the `config_` variables on [lines 4 through 12](https://github.com/martinrue/deploy.sh/blob/master/deploy.sh#L4-L12). Execute a deployment by running `deploy.sh` from the root of your project.

### Project structure
The recommended structure is to have a `deploy` directory at the root of your project, containing your custom `deploy.sh` script, along with your nginx and upstart config files. Example:

```
project
|-- deploy
|   |-- deploy.sh   # executable deploy script
|   |-- app-u.conf  # upstart config file
|   |-- app-n.conf  # nginx config file
```

To create the recommended structure, run the following from within your project directory:

```shell
mkdir deploy && \
cd deploy && \
echo upstart config stub > app-u.conf && \
echo nginx config stub > app-n.conf && \
curl -O https://raw.githubusercontent.com/martinrue/deploy.sh/master/deploy.sh && \
chmod +x deploy.sh
```

### Config
The `config_` variables on [lines 4 through 12](https://github.com/martinrue/deploy.sh/blob/master/deploy.sh#L4-L12) of the script control how the deployment will be executed:

Variable Name       | Description | Required
------------------- | ----------- | --------
`config_server`     | The SSH details of the server to deploy to. | Yes
`config_port`       | Set if you need to use a custom SSH port, defaults to `22`. | No
`config_repo`       | The project git repository URL that'll be cloned for each build, e.g. `git@github.com:user/app.git`. | Yes
`config_localcmd`   | Local command to run before the deployment, e.g. `npm install --production`. | No
`config_remotecmd`  | Remote command to run after a successful deploy, e.g. `npm install --production`. | No
`config_path`       | The path on the server that the app should be deployed to, e.g. `/var/www/app`. | Yes
`config_upstart`    | The relative path (from the root of the project) of the upstart config file, e.g. `deploy/app.conf`. | Yes
`config_nginx`      | The relative path (from the root of the project) of the nginx config file, e.g. `deploy/app`. If this is not set, nginx setup will be skipped. | No
`config_nginx_path` | Set if you need to override the nginx config path, defaults to `/etc/nginx/conf.d`. | No

### Deploying

Run `deploy.sh` from the root of your project:

```shell
$ ./deploy/deploy.sh
info: creating build aeb58ded-2d58-49bb-8089-71141abea22b
info: pushing to server
info: deploying
```

### Limitations
Nginx version 1.8+ is assumed, which means the `config_nginx_path` defaults to `/etc/nginx/conf.d` and your nginx config file must end with `.conf`. If you're deploying to an older version of nginx, you'll have to modify the script to use `sites-enabled`.
