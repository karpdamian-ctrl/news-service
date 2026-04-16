#!/usr/bin/env sh
set -eu

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
