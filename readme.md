# deploy.sh

`deploy.sh` is a simple bash script for creating local builds of a node app and deploying them to an nginx + upstart server via SSH.

## How to use
Simply copy the [deploy.sh](https://raw.githubusercontent.com/martinrue/deploy.sh/master/deploy.sh) script into your project and update the `config_` variables on [lines 4 through 11](https://github.com/martinrue/deploy.sh/blob/master/deploy.sh#L4-L11). Execute a deployment by running `deploy.sh` from the root of your project.

### Project structure
The recommended structure is to have a `deploy` directory at the root of your project, containing your custom `deploy.sh` script, along with your nginx and upstart config files. Example:

```
project
|-- deploy
|   |-- deploy.sh # executable deploy script
|   |-- app.conf  # upstart config file
|   |-- app       # nginx config file
```

To create the recommended structure, run the following from within your project directory:

```shell
mkdir deploy && \
cd deploy && \
echo upstart config stub > app.conf && \
echo nginx config stub > app && \
curl -O https://raw.githubusercontent.com/martinrue/deploy.sh/master/deploy.sh && \
chmod +x deploy.sh
```

### Config
The `config_` variables on [lines 4 through 11](https://github.com/martinrue/deploy.sh/blob/master/deploy.sh#L4-L11) of the script control how the deployment will be executed:

| variable name       | meaning | required |
| ------------------- | ------- | -------- |
| `config_server`     | The SSH details of the server to deploy to. | Yes |
| `config_port`       | Set if you need to use a custom SSH port, defaults to `22`. | No |
| `config_repo`       | The project git repository URL that'll be cloned for each build, e.g. `git@github.com:user/app.git`. | Yes |
| `config_buildcmd`   | Command to run that gets you from a clean git clone to a runnable build, e.g. `npm install --production`. | No |
| `config_path`       | The path on the server that the app should be deployed to, e.g. `/var/www/app`. | Yes |
| `config_upstart`    | The relative path (from the root of the project) of the upstart config file, e.g. `deploy/app.conf`. | Yes |
| `config_nginx`      | The relative path (from the root of the project) of the nginx config file, e.g. `deploy/app`. If this is not set, nginx setup will be skipped. | No |
| `config_nginx_path` | Set if you need to override the nginx config path, defaults to `/etc/nginx/sites-enabled`. | No |

### Deploying

Run `deploy.sh` from the root of your project:

```shell
$ ./deploy/deploy.sh
info: creating build aeb58ded-2d58-49bb-8089-71141abea22b
info: pushing to server
info: deploying
```

### Limitations
As `config_buildcmd` is run locally, the local machine must be capable of producing a build for the remote machine. An example of where this becomes a limitation is when you're developing on OS X but deploying to a Linux server and your project uses an NPM module that requires native compilation. In this case, `deploy.sh` will not be much use to you.