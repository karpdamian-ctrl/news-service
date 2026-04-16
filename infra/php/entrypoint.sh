#!/usr/bin/env sh
set -eu

composer install --no-interaction --prefer-dist

php bin/console doctrine:database:create --if-not-exists --no-interaction
php bin/console doctrine:migrations:migrate --no-interaction
php bin/console app:seed-news --no-interaction

if [ "${APP_ENV:-dev}" = "test" ]; then
  exec tail -f /dev/null
fi

exec php -S 0.0.0.0:8000 -t public
