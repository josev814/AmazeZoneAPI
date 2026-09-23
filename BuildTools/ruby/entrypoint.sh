#!/usr/bin/env bash
set -eo pipefail

# include linux platform in Gemfile.lock to avoid "Your bundle only supports platforms" error when running on linux host
# re-syncs gemfile.lock in case of a possibly edited gemfile
# NOTE: Bundler 4 renamed `--update-bundler` to `--bundler`; the old flag is
# rejected ("Unknown switches") and the BUNDLED WITH stamp would never update.
echo "Adding linux platform to Gemfile.lock..."
bundle lock --bundler \
    && bundle lock --add-platform x86_64-linux

# If the app volume's Gemfile.lock no longer matches the installed bundle
# (e.g. Gemfile/lock edited on the host), sync the installed gems to it.
# `bundle install` re-resolves when the
# lock changed and is a fast no-op otherwise.
echo "Installing gems..."
bundle install

# Create the database if it doesn't exist, but don't fail if it does.
# NOTE: always use `bundle exec` here. A bare `rails` resolves through the
# gem binstubs in GEM_HOME (/usr/local/bundle/bin), which can be pinned to a
# stale version (this volume once held a Rails 7.0 app), and would boot the
# app on the wrong gem set.
echo "Creating database if it doesn't exist..."
bundle exec rails db:create || true

# Run db migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# seed the db
# Skip seeding in the test environment: the test database is scratch space for
# the test suite (see TESTING.md) and must stay free of seeded records.
echo "Seeding database..."
if [ "$RAILS_ENV" != "test" ]; then
  bundle exec rails db:seed
fi

# Remove a potentially pre-existing server.pid for Rails.
echo "Removing pre-existing server.pid if it exists..."
if [ -f "tmp/pids/server.pid" ]; then
  rm -f tmp/pids/server.pid
fi

# launches container command
echo "Launching container command: $@"
exec "$@"
