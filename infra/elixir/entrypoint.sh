#!/usr/bin/env sh
set -eu

# Keep server runtime compilation artifacts separate from ad-hoc `docker compose exec phoenix mix ...`
# commands to avoid Phoenix code reloader stale compile.lock errors.
export MIX_BUILD_PATH="${MIX_BUILD_PATH:-/tmp/news_mix_build}"

mix local.hex --force
mix local.rebar --force
mix deps.get

cd apps/core
mix ecto.create
mix ecto.migrate
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

if [ "${MIX_ENV:-dev}" = "test" ]; then
  exec tail -f /dev/null
fi

cd ../api
exec mix phx.server
