# VCL Setup

## Git

On VCL

generate an ssh key for github

```bash
ssh-keygen -t ed25519 -C "<your_email>"
```

`cat` the location of your .pub key which should be under `/home/<your_user>/.ssh/`

Add that as a deployment key for your git repository on Github

### Clone the repository

Make sure to update the github username in the commands below

On VCL

```bash
sudo apt-get update
sudo apt-get install git -y
eval $(ssh-agent -s)
ssh-add ~/.ssh/<your_ssh_key>
mkdir -p ~/app
cd ~/app
git clone git@github.com:<your_github_username>/AmazeZone.com.git .
```

## Docker
### Install dependencies
This installs docker and it's dependencies along with vim and htop

```bash
bash BuildTools/scripts/vcl/docker_setup.sh
```

### Standup the containers
Run the compose_project.sh with --start, but do so from the root of the project (~/app)

```bash
bash BuildTools/scripts/vcl/compose_project.sh --start
```
This will create a .env file if it doesn't exist by copying the existing example.env file

The env file will
- set the environment as "development"

It will then launch the compose project and be accessible over port 3005 (default; configurable via `API_PORT` in `BuildTools/.env`)

A normal `--start` uses the existing image (it is only built if it is missing).
Pass `--build` to force a rebuild of the image first (e.g. after changing the
`Gemfile`/`Gemfile.lock` or the dockerfile):

```bash
bash BuildTools/scripts/vcl/compose_project.sh --start --build
```

You can verify the compose project is up by running
```bash
sudo docker logs --follow amazezone
```

You'll see this output in the logs
```
The Gemfile's dependencies are satisfied
=> Booting Puma
=> Rails 8.0.2.1 application starting in development 
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 6.6.1 ("Return to Forever")
* Ruby version: ruby 3.4.10 (2026-06-30 revision 2b0b7728dc) +PRISM [x86_64-linux]
*  Min threads: 3
*  Max threads: 3
*  Environment: development
*          PID: 1
* Listening on http://0.0.0.0:3004
Use Ctrl-C to stop
Started GET "/healthz" for 127.0.0.1 at 2026-09-11 18:03:26 +0000
  ActiveRecord::SchemaMigration Load (4.8ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
Processing by Rails::HealthController#show as */*
  Rendering html template
  Rendered html template (Duration: 0.6ms | GC: 0.0ms)
Completed 200 OK in 105ms (Views: 57.3ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 0.0ms)
```

Since we're running in debug mode you will see other output in the logs like the db queries that are running

You'll also see `Started GET "/healthz"` and its responses occasionally get logged. That's how we validate the health of the docker container.

### Teardown the containers
This can be helpful is we sync code and it doesn't update.

Just have the project tear down and that run start again to rebuild it.
```bash
bash BuildTools/scripts/vcl/compose_project.sh --stop
```
This prompts about cleaning up the project's volumes and images (default: no).
Pass `--remove-volumes` / `--remove-images` to clean those up without prompting
(the old stop_project.sh removed all images with `down --rmi all`).
