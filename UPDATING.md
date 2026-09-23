# Updating gems

This document explains how to **install new gems** and **upgrade existing gem
packages** for this Rails API using the dev container, and how to make those
changes take effect in the Docker setup for the current container *and* every
future restart. It pairs with [TESTING.md](TESTING.md) (run the suite
afterwards); the [README's "Adding gems" section](README.md#adding-gems)
covers the same install workflow with a focus on `Gemfile` conventions.

> The workflow in one line: **attach to the container -> `bundle add` (new
> gem) or `bundle update` (upgrade) - both rewrite `Gemfile`/`Gemfile.lock`,
> which live in the bind-mounted repo -> restart the service (the entrypoint's
> `bundle install` syncs the installed gems) -> verify and commit.**

---

## 1. Where gems live in this setup

Three layers matter, and they are persisted differently:

| What | Where | Persisted? |
| --- | --- | --- |
| `Gemfile` and `Gemfile.lock` | Repo root, bind-mounted at `/app` inside the container | **Yes - on your host machine** (and committed to git) |
| Installed gems (`GEM_HOME` = `/usr/local/bundle`, set by `BUNDLE_PATH` in `BuildTools/.env`) | The `gem_cache` named volume | Yes - survives restarts *and* image rebuilds |
| Ruby 3.4.10 + Bundler (lockfile stamp 4.0.21) | The `amazezone_api:local` image | Yes - baked into the image |

Two consequences follow:

- **Editing `Gemfile`/`Gemfile.lock` from inside the container is the same as
  editing it on the host** - the repo is bind-mounted, so the files are
  "saved" the moment a command writes them. No copy-back step exists.
- **The entrypoint (`BuildTools/ruby/entrypoint.sh`) re-syncs on every
  container start**: it runs `bundle lock --bundler` ->
  `bundle lock --add-platform x86_64-linux` -> `bundle install` before
  starting the server. `bundle install` is a fast no-op when the lockfile
  matches the installed gems, and installs whatever changed when it does not.
  This is the mechanism that makes an upgrade "stick" for future restarts.

A running server, however, does **not** reload gem changes on its own - a
restart is what applies them (section 4).

---

## 2. Attach to the dev container

You do **not** need Ruby or Bundler on your host machine - everything happens
inside the container. First make sure the stack is running
(`.\BuildTools\scripts\compose_project.ps1 -Start`). Then use either:

**Option A - VS Code (recommended for day-to-day work).**
Same flow as [README § "Developing in VSCode"](README.md#developing-in-vscode-attach-to-the-running-container):

1. Install the **Microsoft Dev Containers** extension.
2. Command Palette (CTRL+SHIFT+P) -> **Dev Containers: Attach to Running
   Container…** -> select the **`amazezone_api`** container.
3. Open the integrated terminal - it now runs inside the container with
   Ruby, Bundler, and Rails.

**Option B - plain `docker exec` (no editor needed).**

```powershell
docker exec -it amazezone_api bash
```

(or `docker compose -f BuildTools\docker-compose.yml exec ruby bash`).

Sanity-check the shell:

```bash
bundle -v   # Bundler 4.x (lockfile stamp is 4.0.21)
rails -v    # Rails 8.0.x
pwd         # /app - the bind-mounted repo root
```

> If you **rebuild the image** (e.g. `-Start -Build`), the container is recreated and this
> terminal dies, but the stack stays up - just re-attach. If you **stop the stack**
> (`-Stop` removes the container), start the stack again and then re-attach.

---

## 3. Install new gems or upgrade existing ones (updates `Gemfile` + `Gemfile.lock`)

Run these **inside the attached terminal** (i.e. inside the container).
`Gemfile` and `Gemfile.lock` are in the bind-mounted repo, so the changes are
persisted to your machine immediately.

### 3.1 Install a new gem (add it to `Gemfile` + `Gemfile.lock`)

**Option 1 - `bundle add` (easiest; writes both files in one step):**

```bash
bundle add my_gem
```

**Option 2 - edit the `Gemfile` by hand** (repo root; `/app` inside the
container - or just in VS Code), then resolve the lockfile from the attached
terminal:

```bash
bundle lock my_gem     # or plain `bundle lock` to re-resolve the whole bundle
```

(You can also skip that step and let the next restart resolve it - the
entrypoint's `bundle lock --bundler` + `bundle install` handles it.)

`Gemfile` conventions (follow the existing style):

- Pin the version with `~>` to match the existing convention (e.g. `gem 'my_gem', '~> 2.5'`).
- Gems used only for development/testing go under `group :development, :test` (or `group :test`), like `byebug` / `solargraph`.
- Gems with native extensions (e.g. `sqlite3`, `nokogiri`) may need a C library installed in `BuildTools/ruby/dockerfile` (see `libsqlite3-dev` for the sqlite3 gem) - in that case you must rebuild the image (section 4.3), not just restart.

### 3.2 Upgrade one gem (most common)

```bash
bundle update jwt
```

Bundler re-resolves that gem (and its dependencies, only where needed) within
the requirement already in the `Gemfile` (e.g. `gem 'jwt'` -> newest release,
`gem 'jbuilder', '~> 2.12'` -> newest 2.x), and rewrites `Gemfile.lock`.

### 3.3 Move to a newer major version

If the `Gemfile` requirement blocks the version you want, edit the
requirement first (in the `Gemfile` at the repo root - in VS Code or with any
editor), keep the repo's `~>` pinning convention, then re-resolve:

```bash
# Gemfile:  gem 'rspec-rails', '~> 7.0'   ->   gem 'rspec-rails', '~> 8.0'
bundle update rspec-rails
```

### 3.4 Other useful variants

| Goal | Command |
| --- | --- |
| Upgrade several specific gems at once | `bundle update jwt jbuilder puma` |
| Upgrade the *entire* bundle | `bundle update` (big jump - run the full test suite afterwards) |
| Re-resolve the lock only, without changing the `Gemfile` requirement | `bundle lock jwt` |
| Add a completely new gem (writes both files) | `bundle add my_gem` (covered in section 3.1) |
| Downgrade a gem | pin the old version in the `Gemfile` (e.g. `gem 'puma', '~> 6.4'`), then `bundle update puma` |

### 3.5 Check what changed, then commit

```bash
git diff Gemfile Gemfile.lock
```

Review the diff (note any dependency bumps Bundler pulled in along the way).
`Gemfile.lock` **is committed to this repo**, so commit both files together:

```powershell
git add Gemfile Gemfile.lock
git commit -m "Upgrade jwt to <version>"
```

### 3.6 What NOT to do

- **Do not use plain `gem install` to add or upgrade an app gem.** It drops the gem
  into `GEM_HOME` (the persisted `gem_cache` volume) *without* touching
  `Gemfile`/`Gemfile.lock`. The next start's `bundle install` does not see it,
  and a stray version sitting in the volume can shadow the one the lockfile
  says to use. `bundle add` (new gems) and `bundle update` (upgrades) are the
  correct tools here.
- **Do NOT `gem install bundler`** (pinned or not). It lands in `GEM_HOME`,
  which the `gem_cache` volume persists, and can shadow the default Bundler
  the image ships. The lockfile's `BUNDLED WITH` stamp is maintained for you
  by `bundle lock --bundler` in the dockerfile and entrypoint (Bundler 4's
  name for the former `--update-bundler`).

---

## 4. Make the change take effect in the containers

The lockfile is already persisted (section 3), so the only thing left is to
get the *installed* gems in sync with it.

### 4.1 Restart the `ruby` service (the canonical "apply" action)

```powershell
docker compose -f BuildTools\docker-compose.yml restart ruby
```

(equivalently `docker restart amazezone_api`, or the restart icon for the
`amazezone_api` container in Docker Desktop).

A `restart` re-runs the **full entrypoint pipeline**:
`bundle lock --bundler` -> `bundle lock --add-platform x86_64-linux` ->
**`bundle install`** -> `rails db:create` -> `rails db:migrate` ->
`rails db:seed` -> `rails server`. The `bundle install` step detects that
`Gemfile.lock` changed and installs the new/updated gem versions into the
persisted `gem_cache` volume. That is the entire procedure that makes the
change survive and apply on **all future restarts** - after the first
restart, the gems are already in the volume, so subsequent starts are a fast
no-op.

> The `test` service is not a long-running container, but it runs the same
> entrypoint, so the next
> `docker compose -f BuildTools\docker-compose.yml --profile test run --rm test`
> automatically uses the upgraded gems as well.

### 4.2 Verify the new version is active

Watch the start logs for the install, then confirm the version:

```powershell
docker compose -f BuildTools\docker-compose.yml logs ruby
docker exec amazezone_api bundle list
```

or, from the attached terminal:

```bash
bundle list | grep jwt
bundle exec rails runner 'puts JWT::VERSION'
```

and confirm the API is healthy: `http://localhost:3005/healthz`.

### 4.3 (Optional) Bake the gems into the image

Restarting installs into the `gem_cache` volume, which is all this machine
needs. If you are preparing a **fresh environment** (new machine, VCL, CI
image) and want the gems baked into the image itself, rebuild:

```powershell
.\BuildTools\scripts\compose_project.ps1 -Start -Build
```

(equivalent to `docker compose -f BuildTools\docker-compose.yml up -d --build`;
a plain `up -d` does **not** rebuild an existing image.)

---

## 5. After adding or upgrading: prove nothing broke

1. **Smoke test** the dev server (`/healthz`, one or two API calls).
2. **Run the full RSpec suite** - it picks up the new gems automatically
   (same entrypoint, `gem_cache` volume):

   ```powershell
   docker compose -f BuildTools\docker-compose.yml --profile test run --rm test
   ```

   (or run it from an attached terminal, see [TESTING.md](TESTING.md)).
3. **Commit** `Gemfile` + `Gemfile.lock` (and any code changes the new
   version forced) together.

---

## 6. Caveats and recovery

- **Native extensions.** If the new gem version requires a C library that the
  image does not ship (e.g. a different `libsqlite3-dev`), no restart can fix
  it - install the package in `BuildTools/ruby/dockerfile` and rebuild with
  `compose_project.ps1 -Start -Build`.
- **Rails/Ruby compatibility.** This app runs Rails 8.0.x on Ruby 3.4.10. If
  an upgrade fails to resolve, the usual culprit is a gem that is not yet
  compatible with that combination - pin it (e.g. the `json ~> 2` lock noted
  in the `Gemfile`) instead of forcing a newer one.
- **Stale or misbehaving gem in the volume.** The clean fix is a full
  reinstall:

  ```powershell
  .\BuildTools\scripts\compose_project.ps1 -Stop -RemoveVolumes
  .\BuildTools\scripts\compose_project.ps1 -Start
  ```

  (or `docker compose -f BuildTools\docker-compose.yml down --volumes` and
  start again). The next start re-runs `bundle install` and rebuilds the
  `gem_cache` volume from the committed lockfile.
- **Reverting an upgrade.** Revert the `Gemfile`/`Gemfile.lock` commit
  (`git revert ...`), then restart per section 4.1 - the entrypoint's
  `bundle install` re-syncs the installed gems to the restored lockfile.

---

## Quick reference (cheat sheet)

```powershell
# 0. Stack running?
.\BuildTools\scripts\compose_project.ps1 -Start

# 1. Attach (or use the VS Code Dev Containers attach instead)
docker exec -it amazezone_api bash

# 2. Inside the container (writes Gemfile/Gemfile.lock in the bind-mounted repo)
bundle add my_gem                      # install a new gem
bundle update jwt                      # upgrade (or: bundle update jwt jbuilder)
bundle lock jwt                        # re-resolve without touching the Gemfile

# 3. Back on the host: review + commit
exit
git diff Gemfile Gemfile.lock
git add Gemfile Gemfile.lock && git commit -m "Add my_gem / upgrade jwt"

# 4. Apply: restart so the entrypoint's bundle install syncs the installed gems
docker compose -f BuildTools\docker-compose.yml restart ruby

# 5. Verify
docker exec amazezone_api bundle list
docker compose -f BuildTools\docker-compose.yml --profile test run --rm test

# Optional: bake into the image for a fresh environment
.\BuildTools\scripts\compose_project.ps1 -Start -Build
```


