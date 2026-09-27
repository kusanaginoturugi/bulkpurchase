#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "使い方: ./scripts/import-rails-data.sh ../import/rails-data.sql" >&2
  exit 1
fi

npx wrangler d1 execute DB --remote --file "$1"
