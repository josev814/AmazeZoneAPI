# Testing AmazeZoneAPI

This document explains how to run the **RSpec** test suite for this Rails API,
how the test environment is wired into our Docker setup, and how to write and
extend specs. It covers both the day-to-day developer workflow (attaching to the
container from VS Code) and a headless/CI workflow (a dedicated `test`
compose service).

> The suite lives in `spec/`. Data is built with [FactoryBot]
> (`spec/factories/`). There is no Minitest suite anymore - the former `test/`
> files were ported to RSpec (see [Spec layout](#spec-layout)).

---

## 1. How the Rails environment flows through Docker

The single most important idea: **a container is just a runtime; what matters
for testing is the `RAILS_ENV` environment variable.** The same image can run
as `development`, `test`, or `production`. Rails picks which code to load
(`config/environments/<env>.rb`) and which database to use
(`config/database.yml`) purely from `RAILS_ENV`.

There are three layers that can set `RAILS_ENV`, in order of **increasing**
precedence:

| Precedence | Where set | Value | Purpose |
| --- | --- | --- | --- |
| Lowest | `BuildTools/ruby/dockerfile` -> `ENV RAILS_ENV=production` | `production` | A sane default if the image is ever run with no overrides. |
| Middle | `BuildTools/.env` (loaded via `env_file` in `docker-compose.yml`) | `development` | What the **dev server** (`ruby` service) runs as. |
| Highest | A service's `environment:` block, or `docker compose run -e` | `test` (for the test service) | Forces the test environment for the `test` service. |

So when you see "the image is built for production but compose overrides it to
development," that is exactly by design and it is *not* a problem for testing:

- The `ruby` service (the API server) runs as **development** - that is what
  you want for `rails server`.
- Tests are a **separate** concern. We force `RAILS_ENV=test` for the test run,
  which takes precedence over the `.env` value, so tests *never* touch the
  development database. They use `db/test.sqlite3` instead.

In short: **you do not run tests "against the dev container."** You run them in
the `test` environment. The dev container and the test run can even use the same
image - only `RAILS_ENV` differs.

---

## 2. Two ways to run the suite

### A. Attach from VS Code (recommended for day-to-day)

Ruby is **not** installed on the host - it only exists inside the container.
The intended workflow is to attach your editor to the running container using
the **Microsoft Dev Containers** extension, which gives you a terminal *inside*
the container (with its Ruby/Bundler/RSpec).

1. Start the stack (this starts the `ruby` service only - see
   [Why a dedicated `test` service](#why-a-dedicated-test-service)):

   ```powershell
   .\BuildTools\scripts\compose_project.ps1 -Start
   ```

2. In VS Code, use **Dev Containers: Attach to Running Container…** and pick the
   `amazezone_api` container (the `ruby` service).

3. Open the VS Code integrated terminal (it now runs inside the container).
   `RAILS_ENV` is already `development` from the container env, but for tests we
   want the `test` environment. Prepare the test database once, then run:

   ```bash
   # One-time / after schema or Gemfile changes:
   RAILS_ENV=test rails db:prepare

   # Full suite:
   RAILS_ENV=test bundle exec rspec

   # A single file:
   RAILS_ENV=test bundle exec rspec spec/requests/auth_spec.rb

   # A single example (by line number):
   RAILS_ENV=test bundle exec rspec spec/requests/auth_spec.rb:12
   ```

   > Tip: `rails db:prepare` creates/migrates `db/test.sqlite3` and loads the
   > schema. You normally only need it when you change migrations or the Gemfile
   > - not before every test run.

### B. Headless / CI - the `test` compose service

If you are not attaching an editor (e.g. on a build agent, or you just want a
one-shot run), use the dedicated `test` service defined in
[`BuildTools/docker-compose.yml`](BuildTools/docker-compose.yml). It reuses the
same image, bind-mounts the repo (so spec edits are picked up without a
rebuild), forces `RAILS_ENV=test`, and runs `bundle exec rspec` then exits.

```bash
# Full suite (one-shot; the exit code is RSpec's exit code):
docker compose -f BuildTools/docker-compose.yml --profile test run --rm test

# A single file:
docker compose -f BuildTools/docker-compose.yml --profile test run --rm test \
  bundle exec rspec spec/requests/auth_spec.rb

# A single example:
docker compose -f BuildTools/docker-compose.yml --profile test run --rm test \
  bundle exec rspec spec/requests/auth_spec.rb:12
```

Notes:
- `--profile test` is **required** - the service is gated behind that profile so
  it never starts on a normal `up` (see next section).
- `--rm` removes the one-shot container after it finishes.
- The exit code is RSpec's, so `0` = all green, non-zero = failures. This makes
  it trivial to use in CI or a script.

---

## Why a dedicated `test` service (and why it's behind a profile)

A plain `docker compose up` starts **every** service in the compose file. If the
`test` service had no profile, then every time a developer ran
`compose_project.ps1 -Start` (or `docker compose up`) to start the dev server,
Compose would *also* spin up the `test` service, run the entire suite, and let it
exit - an unwanted side effect on every startup.

To prevent that, the `test` service is declared with `profiles: ["test"]`.
Services with a profile are **ignored** by `up`/`down`/`ps` unless that profile
is explicitly enabled. The result:

- `docker compose up` / `compose_project.ps1 -Start` -> starts **only** `ruby`.
  The `test` service stays dormant. ✅
- To run tests, you explicitly enable the profile
  (`--profile test run --rm test`). ✅

This keeps the dev startup path unchanged and opt-in for tests, with no changes
needed to the existing PowerShell scripts.

Other reasons for a separate service (rather than just running rspec in the
`ruby` container):
- **Clean test database** - the test service runs with `RAILS_ENV=test`, so it
  uses `db/test.sqlite3` and never mutates the development database.
- **No port/healthcheck contention** - it doesn't bind `3005` or run the server
  healthcheck.
- **One-shot semantics** - it runs and exits, which is what you want for a test
  run (and gives a clean exit code).

---

## 3. The test environment (what's different)

When `RAILS_ENV=test`:
- Loads `config/environments/test.rb` - exceptions are raised (no error pages),
  caching is disabled, and eager loading is enabled only when `CI` is set.
- Uses the `test` entry in `config/database.yml` -> **`db/test.sqlite3`**
  (separate from `db/development.sqlite3`).
- Each example is wrapped in a database transaction and rolled back afterwards,
  so the suite is isolated and leaves no data behind.

  > Note: in **rspec-rails 7.x** transactional fixtures are *off* by default
  > (`RSpec.configuration.use_transactional_fixtures` is `nil`). Without
  > `config.use_transactional_fixtures = true` (set in `spec/rails_helper.rb`),
  > records created by specs would be committed to `db/test.sqlite3` and leak
  > between examples/runs, and request specs (which run in a separate thread)
  > could not see data created in the spec. Enabling it makes both work as
  > expected.

### Database preparation & the seed guard

- `db/test.sqlite3` is created and migrated by `rails db:prepare` (or the
  entrypoint's `rails db:create` / `rails db:migrate`).
- The entrypoint (`BuildTools/ruby/entrypoint.sh`) **skips `rails db:seed` when
  `RAILS_ENV=test`**. This is deliberate: the test database is scratch space and
  must not be polluted by seeded records (which could break count/uniqueness
  assertions). Development and production still seed as before.

---

## 4. Spec layout

The Minitest suite under `test/` has been ported to RSpec under `spec/`:

| Old (Minitest, removed) | New (RSpec) |
| --- | --- |
| `test/models/user_test.rb` | `spec/models/user_spec.rb` |
| `test/models/product_test.rb` | `spec/models/product_spec.rb` |
| `test/controllers/auth_controller_test.rb` | `spec/requests/auth_spec.rb` |
| `test/controllers/users_controller_test.rb` | `spec/requests/users_spec.rb` |
| *(none - ProductsController was untested)* | `spec/requests/products_spec.rb` |
| `test/channels/application_cable/connection_test.rb` | `spec/channels/application_cable/connection_spec.rb` |
| `test/fixtures/*.yml` | Replaced by `spec/factories/` |

Key files:
- `.rspec` - RSpec CLI options (`--require spec_helper`).
- `spec/spec_helper.rb` - Rails-agnostic RSpec config.
- `spec/rails_helper.rb` - loads the Rails environment, requires support files,
  and keeps the test schema in sync.
- `spec/support/factory_bot.rb` - opts examples into FactoryBot syntax.
- `spec/factories/users.rb`, `spec/factories/products.rb` - record factories.

> Note: request specs (the `spec/requests/*` files) are the RSpec replacement for
> the old controller specs. They exercise the full stack (routing -> controller ->
> model), which is the idiomatic way to test an API with RSpec.

---

## 5. Writing and extending specs

### Authentication in request specs

Most endpoints require a bearer token. The pattern used in
`spec/requests/products_spec.rb` is: create a user, log in via `POST /auth/login`
to obtain a real JWT, then send it as `Authorization: Bearer <token>`.

```ruby
let(:user) { create(:user, password: "password123", password_confirmation: "password123") }
let(:auth_token) do
  post "/auth/login", params: { email_address: user.email_address, password: "password123" }
  JSON.parse(response.body)["auth_token"]
end
let(:auth_headers) { { "Authorization" => "Bearer #{auth_token}" } }
```

### Adding a new spec

1. Create the file in the matching directory (`spec/models`, `spec/requests`, …).
2. `require "rails_helper"` at the top.
3. Use factories (`create(:user)`, `build(:product)`) for data.
4. For request specs, assert on `response` status and `JSON.parse(response.body)`.

### Running a subset

```bash
# by file
bundle exec rspec spec/requests/auth_spec.rb
# by example description
bundle exec rspec -e "responds with 401"
# by tag (if you add :focus or custom tags)
bundle exec rspec --tag focus
```

### Code coverage (SimpleCov)

Coverage is measured automatically on every spec run - no extra flags needed.
`spec/spec_helper.rb` (loaded first, before Rails boots) starts
[SimpleCov](https://github.com/simplecov-rspec/simplecov), which is declared in
the `:development, :test` group of the `Gemfile`. When the run finishes, the
report is written to `coverage/`:

- `coverage/index.html` - self-contained HTML report (open in any browser;
  shows line-by-line hits per file)

Coverage is reported as HTML only - the suite does not configure any additional
SimpleCov formatter. Application code (`app/`, `lib/`, `config/`, `db/`, and
other top-level Ruby files) is measured; the spec suite itself, `test/`,
`vendor/`, and the container's gem path are excluded. The `coverage/` directory
is git-ignored - commit the *code*, not the report.

> Implementation note: `config/boot.rb` skips Bootsnap when SimpleCov is active
> (`require "bootsnap/setup" unless defined?(SimpleCov)`). On Ruby 3.4,
> Bootsnap's ISeq cache calls `RubyVM::InstructionSequence#to_binary`, which
> raises `should not compile with coverage` while coverage is enabled. Normal
> (non-instrumented) boots still use Bootsnap.

---

## 6. Troubleshooting

- **Gem errors after adding a gem** - the entrypoint runs `bundle lock` +
  `bundle install` on start, and the repo is bind-mounted, so a Gemfile change is
  picked up on the next container start. Restart the stack (or rebuild) so the
  gems install, then run `RAILS_ENV=test rails db:prepare`.
- **Schema out of date / "cannot open" the test DB** - run
  `RAILS_ENV=test rails db:prepare` to (re)create/migrate the test database.
- **Tests touch the dev database / seed data appears** - confirm you are running
  with `RAILS_ENV=test`. The test service sets it automatically; when running
  from an attached terminal, prefix the command with `RAILS_ENV=test`.
- **A normal `up` started the test suite** - it shouldn't; the `test` service is
  behind the `test` profile. If you ran `--profile test up` by mistake, that is
  expected. Plain `up` never starts it.
- **JWT / 401 in specs** - ensure the token was obtained in the *same* example
  (the `let(:auth_token)` helper does this) and that the user exists.

---

[FactoryBot]: https://github.com/thoughtbot/factory_bot