# Docker App Setup

Docker Compose setup for the Amazezone API application (a Ruby on Rails app backed by SQLite).

Starts a single service `ruby`: this builds and runs the `amazezone_api` container that is the Rails server with the application code.

This document focuses on Windows users, but there are helper scripts for VCL that can also be used on Linux

## Prerequisites
- Internet access for the first image pulls

Windows Users:
- Windows 10/11 with PowerShell (the helper scripts target Windows)
- Docker Desktop with the WSL2 backend (install it with the script below if needed)

Mac/Linux Users:
- Install docker desktop or the docker cli, whichever you are more comfortable with

> NOTE: VCL Users
>
> VCL is Linux and there's documentation with how to get up and running with VCL and docker in the BuildTools/scripts/vcl directory

## Quick Start

1. **Install or start Docker Desktop** (no-op if already running):

   ```powershell
   .\BuildTools\scripts\install_docker.ps1
   ```

2. **Create `BuildTools\.env` in VS Code**:
   - In the Explorer, open `BuildTools/example.env`, then select all (Ctrl+A) and copy (Ctrl+C).
   - In the `BuildTools/` folder, right-click -> *New File…*, name it `.env`, and paste (Ctrl+V).
   
3. **Build and start the stack**:

   ```powershell
   .\BuildTools\scripts\compose_project.ps1 -Start
   ```

4. **Open the AmazeZone app** in your browser: `http://localhost:3005`

5. **Stop the stack** when done:

   ```powershell
   .\BuildTools\scripts\compose_project.ps1 -Stop
   ```

## Docker Installation Script

`scripts\install_docker.ps1` - installs or starts Docker Desktop on Windows (WSL2 backend).

- Docker already running -> prints a message and exits.
- Docker installed but stopped -> prompts to start Docker Desktop (default: yes) and waits up to 5 minutes for the daemon.
- Docker not installed -> must be run from an **elevated (Administrator)** prompt; enables the WSL feature if missing (reboot + re-run in that case), downloads the Docker Desktop installer to `%USERPROFILE%\Downloads`, and launches it.

```powershell
.\BuildTools\scripts\install_docker.ps1 [-DockerPath <path>] [-Help]
```

## Project Startup Script

`scripts\compose_project.ps1` - starts or stops the Docker Compose project (manages `BuildTools\docker-compose.yml` by default).

- `-Start` -> `docker compose up -d`, then prints service status. The image is built automatically if it is missing, or always when `-Build` is passed.
- `-Build` -> used with `-Start`: adds `--build` to the up command, forcing the image to be rebuilt (use this after changing `Gemfile`/`Gemfile.lock` or the dockerfile if you want the gems baked into the image).
- `-Stop` -> `docker compose down --remove-orphans`; unless `-RemoveVolumes` / `-RemoveImages` are passed, it prompts about cleaning up volumes and images (default: no). `-RemoveVolumes` removes the project's named `gem_cache` volume (which holds the installed gems, so the next start reinstalls them); `-RemoveImages` removes the images, forcing a full rebuild the next start.
- `-ComposeFile <path>` -> manage a different compose file.
- `-Cleanup` -> reserved; no-op in the current implementation (cleanup is controlled by `-RemoveVolumes` / `-RemoveImages`).
- `-Help` -> usage.

```powershell
.\BuildTools\scripts\compose_project.ps1 -Start
.\BuildTools\scripts\compose_project.ps1 -Start -Build
.\BuildTools\scripts\compose_project.ps1 -Stop
.\BuildTools\scripts\compose_project.ps1 -Stop -RemoveVolumes -RemoveImages
```

### Service overview

| Service | Container | Host port | Notes |
| --- | --- | --- | --- |
| ruby | `amazezone_api` | 3005 (default; set `API_PORT` in `.env` to change the host port) | image `amazezone_api:local`; repo root is bind-mounted at `/app`; `CMD` is `bundle exec rails server -b 0.0.0.0 --port 3005` (the container always listens on 3005; `bundle exec` keeps the server on the locked gem set even if stale gem binstubs linger in the `gem_cache` volume) |
| test | `amazezone_api_test` | - | image `amazezone_api:local`; runs the RSpec suite and exits. **Gated behind the `test` profile**, so it is *not* started by a normal `up`. |

### Container behavior

- Entrypoint (`ruby/entrypoint.sh`) runs `bundle lock --bundler`, `bundle lock --add-platform x86_64-linux`, `bundle install`, `rails db:create`, `rails db:migrate`, and `rails db:seed` before starting the server - so the SQLite database under `db/` (repo root) is created and migrated automatically on first start. **When `RAILS_ENV=test`, `rails db:seed` is skipped** so the test database stays clean for the suite.
- Healthcheck: `docker-compose.yml` probes `http://localhost:3005/healthz` (the `rails/health#show` endpoint from `config/routes.rb`) every 90 seconds.

### Gem cache volume & Bundler (important)

- The `gem_cache` volume persists the container's `GEM_HOME` (`/usr/local/bundle`), so installed gems survive image rebuilds. This is what makes restarts fast - and what makes `gem install <pinned version>` dangerous: an explicitly installed gem (e.g. an old `bundler`) lands there, survives rebuilds, and can shadow the version the image ships. The default Bundler shipped with the Ruby image is the one this setup relies on; the lockfile stamp is kept current by `bundle lock --bundler` in the dockerfile and entrypoint (Bundler 4's name for the former `--update-bundler`).
- If a misbehaving/stale gem ever appears, the clean fix is a full reinstall: `compose_project.ps1 -Stop -RemoveVolumes` (or `docker compose -f BuildTools\docker-compose.yml down --volumes`) and start again.
- Known cleanup: an orphaned, differently-cased volume `AmazezoneAPI_gem_cache` (capital A) is not mounted by the current compose file and can be removed with `docker volume rm AmazezoneAPI_gem_cache`. Do not remove the active `amazezoneapi_gem_cache` volume while you are relying on it.

### Running tests

The RSpec suite runs in the `test` environment (`RAILS_ENV=test`, `db/test.sqlite3`).
Because the `test` service is behind the `test` profile, a normal `docker compose up`
(or `compose_project.ps1 -Start`) starts **only** the `ruby` service - it never runs
the tests. To run the suite, enable the profile explicitly:

```powershell
docker compose -f BuildTools\docker-compose.yml --profile test run --rm test
```

For the full workflow (including running from an attached VS Code terminal via the
Dev Containers extension, running single files/examples, writing new specs, and
troubleshooting), see the root [`TESTING.md`](../TESTING.md).
