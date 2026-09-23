# AmazeZoneAPI

This guide provides instructions to set up the AmazeZone API (a Ruby on Rails
application backed by SQLite) using Docker. This backend works together with the
AmazeZone frontend, a React + TypeScript app, available on
[GitHub](https://github.com/efg/AmazeZone-Frontend).

## Prerequisites

1. VSCode
2. Git
3. Docker
    - Windows users install Docker Desktop
4. Clone this repo

## Getting up and running

### Open VSCode and clone this repo

- CTRL + SHIFT + P will open the VSCode command palette
- Type Git: Clone in the palette window
- Press enter to select it and then paste the git url for the repo
- You will be asked to save the repo to a local directory
- After selecting the repository destination, you can have it open in the current window or a new window of VSCode

### Ensure that Docker is running

>NOTE:
>
>Windows users can run the `BuildTools/scripts/install_docker.ps1` script which will ensure that it's installed and is running. Full script details: [BuildTools/README.md](BuildTools/README.md)

### Configure the environment

Open this project in VSCode

Copy `BuildTools/example.env` to `BuildTools/.env` (step-by-step instructions: [BuildTools/README.md](BuildTools/README.md))

You should not need to change these settings. Note that `.env` holds the Rails
environment (`RAILS_ENV=development`), logging/static-file flags, coverage
flags, `BUNDLE_PATH`, and the Node environment. The Ruby and OS versions are
set as Docker build args in `BuildTools/ruby/dockerfile` (`RUBY_VERSION`,
`RUBY_OS`), not in `.env`.

### Launch the docker compose stack

Open your terminal in VSCode, CTRL + SHIFT + `

>NOTE: Windows PowerShell users can use the `BuildTools/scripts/compose_project.ps1` script (full options: [BuildTools/README.md](BuildTools/README.md))

```pwsh
docker compose -f BuildTools/docker-compose.yml up -d
```

The docker compose stack will run the Rails server on host port 3005 by default. You can access it on [http://localhost:3005](http://localhost:3005) (the `/healthz` health endpoint is probed every 90 seconds by the compose healthcheck).

>NOTE: To expose the API on a different host port, set `API_PORT` in `BuildTools/.env` (e.g. `API_PORT=3006`) and restart the stack. The container itself always listens on port 3005 - only the host-side mapping changes. If you change the port, make sure the frontend's `VITE_RUBY_API_URL` points at the new host port.

> NOTE:
>
> The container entrypoint creates the database if it is missing, then runs migrations and seeds, so the SQLite file under `db/` (repo root) gets generated when the container starts up.
>
> If a sqlite3 file already exists when doing `docker compose up -d`, or when stopping/starting the container, it will not overwrite the `development.sqlite3` file.

#### To get a fresh sqlite3 file:

- using the command line
  ```pwsh
  docker exec -it amazezone_api /bin/bash -c "rm /app/db/development.sqlite3; rails db:migrate"
  ```
- using vscode/docker:
  - in vscode navigate to `db` (repo root)
  - delete the `development.sqlite3` file
  - restart the docker container called `amazezone_api`
    - this can be done via docker desktop using the restart icon
    - via the command line
      ```pwsh
      docker compose -f BuildTools/docker-compose.yml restart ruby
      ```

### Developing in VSCode (attach to the running container)

You do **not** need Ruby on your host machine - everything lives in the
container. To get a terminal with Ruby, Bundler, and Rails:

1. Install the **Microsoft Dev Containers** extension in VSCode
2. Make sure the stack is running (`compose_project.ps1 -Start`)
3. Command Palette (CTRL + SHIFT + P) -> **Dev Containers: Attach to Running Container…** -> select the **`amazezone_api`** container
4. Open the integrated terminal - it now runs **inside** the container. Use it for `rails console`, `bundle exec rails ...`, `bundle exec rspec`, etc.

Notes:

- The repo is bind-mounted at `/app`, so file edits you make in VSCode are live inside the container.
- If you **rebuild the image** (e.g. `compose_project.ps1 -Start -Build`), the container is recreated and the attached terminal dies, but the stack stays up - just re-attach (Command Palette -> **Dev Containers: Attach to Running Container…** -> `amazezone_api`).
- If you **stop the stack** (`compose_project.ps1 -Stop` runs `docker compose down`, which removes the container), the attach dies with it - start the stack again, then re-attach.
- Test-specific steps (preparing `db/test.sqlite3`, running the suite) are in [TESTING.md](TESTING.md).

### Working with the AmazeZone-Frontend

The frontend and this API are separate Docker Compose projects. For the
frontend to communicate with this API, two environment settings must match:

| Where | Setting | Must equal |
| --- | --- | --- |
| Frontend repo: `app/.env.dev` | `VITE_RUBY_API_URL` | this API's host URL, i.e. `http://localhost:3005` (the port published in `BuildTools/docker-compose.yml`) |
| This repo: `BuildTools/.env` | `VITE_URL` | the frontend's origin (scheme://host:port where your browser loads the app) - used by `config/initializers/cors.rb` to allow cross-origin requests |

See `config/initializers/cors.rb` here and the frontend repo's own
documentation for details.

## Adding gems

You do NOT need Ruby or Bundler on your host machine - the container installs the gems for you. The entrypoint (`BuildTools/ruby/entrypoint.sh`) re-syncs `Gemfile.lock` (via `bundle lock --bundler` + `bundle lock --add-platform x86_64-linux`) and runs `bundle install` on every container start, installing into the persisted `gem_cache` volume.

1. Add the gem to the `Gemfile` (repo root).
   - Pin the version with `~>` to match the existing convention (e.g. `gem 'my_gem', '~> 2.5'`).
   - Gems used only for development/testing go under `group :development, :test` (or `group :test`), like `byebug` / `solargraph`.
   - Gems with native extensions (e.g. `sqlite3`, `nokogiri`) may need a C library installed in `BuildTools/ruby/dockerfile` (see `libsqlite3-dev` for the sqlite3 gem).

2. Apply the change. Pick one:
   - **Restart the stack** (fastest - installs the gem into the `gem_cache` volume, does not touch the built image):

      ```pwsh
      docker compose -f BuildTools/docker-compose.yml restart ruby
      ```

   - **Rebuild the image** (bakes the gem into the image; use for fresh environments or VCL):

      ```pwsh
      .\BuildTools\scripts\compose_project.ps1 -Start -Build
      ```

      This is equivalent to `docker compose -f BuildTools/docker-compose.yml up -d --build`. Note: a plain `up -d` does NOT rebuild an existing image.

3. Verify the gem was installed:

   ```pwsh
   docker compose -f BuildTools/docker-compose.yml logs ruby
   # or
   docker exec -it amazezone_api bundle list
   ```

   and confirm the gem appears in `Gemfile.lock`.

Notes:
- `Gemfile.lock` is committed to the repo and is re-synced automatically by the entrypoint on restart, so the new gem will appear in it.
- Restarting runs the full entrypoint (`bundle lock` -> `bundle install` -> `db:create` -> `db:migrate` -> `db:seed` -> server), so it is the canonical "apply my change" action.
- If you previously stopped with `-RemoveVolumes`, the gems must be reinstalled on the next start (the `gem_cache` volume is gone).
- Do NOT `gem install bundler` (pinned or not) inside this setup - it lands in `GEM_HOME`, which the `gem_cache` volume persists, and can shadow the default Bundler. The lockfile stamp is maintained by `bundle lock --bundler` (Bundler 4's name for the old `--update-bundler`) in the dockerfile and entrypoint.

For the full gem workflow from an attached container - including **installing** a new gem or **upgrading** an existing gem and how the change applies to future restarts - see [UPDATING.md](UPDATING.md).

## Testing

This project is tested with **RSpec** (see the `spec/` directory). To run the
suite, prepare the test database and run RSpec - either by attaching to the
container from VS Code (Dev Containers extension) or via the dedicated `test`
compose service. Full instructions, the environment/precedence details, and how
to write new specs are in [`TESTING.md`](TESTING.md).

Quick start (headless / CI):

```bash
docker compose -f BuildTools/docker-compose.yml --profile test run --rm test
```

> The `test` service is gated behind the `test` profile, so a normal
> `docker compose up` (or `BuildTools\scripts\compose_project.ps1 -Start`)
> never starts it - tests only run when you ask for them.

---

In case of any issues, please open an issue on
[GitHub](https://github.com/efg/AmazeZoneAPI). For general questions, use the
course Moodle forums.