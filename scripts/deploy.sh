#!/usr/bin/env bash
set -euxo pipefail

APP_ROOT="/home/admin/bulkpurchase"
MISE_BIN="/home/admin/.local/bin"
RUBY_BIN="/home/admin/.local/share/mise/installs/ruby/3.4.8/bin"

cd "$APP_ROOT"

export HOME="/home/admin"
export PATH="$MISE_BIN:$RUBY_BIN:$PATH"
export RAILS_ENV="production"
export BUNDLE_GEMFILE="$APP_ROOT/Gemfile"
export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

git config core.fileMode false

git fetch origin
git checkout -- app/assets/builds/tailwind.css
git pull --ff-only origin main

bundle config set deployment true
bundle config set without 'development test'
bundle install
bin/rails db:migrate
bin/rails assets:precompile

sudo -n /usr/bin/systemctl restart bulkpurchase.service
sudo -n /usr/bin/systemctl is-active bulkpurchase.service
