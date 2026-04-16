#!/usr/bin/env sh
set -eu

composer install --no-interaction --prefer-dist

php bin/console doctrine:database:create --if-not-exists --no-interaction
php bin/console doctrine:migrations:migrate --no-interaction

if [ "${APP_ENV:-dev}" = "test" ]; then
  exec tail -f /dev/null
fi

php bin/console app:seed-users --no-interaction

exec php -S 0.0.0.0:8000 -t public
