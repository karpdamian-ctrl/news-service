# News Platform (Dev/Test)

Projekt portfolio oparty o mikroserwisy:
- `symfony` (PHP + EasyAdmin)
- `phoenix` (Elixir/Phoenix umbrella)
- `core` (subapka Elixir odpowiedzialna za warstwę danych / Repo)
- osobne PostgreSQL: `php_db` i `elixir_db`
- Redis + Redis Commander
- RabbitMQ + RabbitMQ Management
- Elasticsearch + Kibana + Filebeat (zbieranie logów kontenerów)

## Wymagania

- Docker + Docker Compose
- Linux/Ubuntu: uruchamiaj z `LOCAL_UID` i `LOCAL_GID`, żeby nie mieszać uprawnień plików.

## Start (DEV)

```bash
LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose up -d --build --force-recreate
```

## Start (TEST / CI)

```bash
LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) \
  docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build --force-recreate
```

## Stop / Cleanup

Zatrzymanie:
```bash
docker compose down
```

Zatrzymanie + usunięcie wolumenów (reset danych):
```bash
docker compose down -v
```

Usunięcie osieroconych kontenerów po zmianie nazw serwisów:
```bash
docker compose down --remove-orphans
```

## Status i logi

Status serwisów:
```bash
docker compose ps
```

Podgląd logów (całość):
```bash
docker compose logs -f
```

Podgląd logów pojedynczego serwisu:
```bash
docker compose logs -f symfony
docker compose logs -f phoenix
docker compose logs -f filebeat
```

## Adresy i panele

- Symfony: http://localhost:8080
- Symfony login: http://localhost:8080/login
- EasyAdmin: http://localhost:8080/admin
- Phoenix: http://localhost:4000
- Redis Commander: http://localhost:8081
- RabbitMQ Management: http://localhost:15672
- Kibana: http://localhost:5601
- Elasticsearch API: http://localhost:9200

## Loginy / hasła

RabbitMQ Management:
- login: `news`
- hasło: `news`

EasyAdmin (seed):
- admin: `admin@news.local` / `admin123`
- redactor: `redactor@news.local` / `redactor123`

Pozostałe panele są w dev bez dodatkowego logowania.

## Najczęstsze komendy `exec`

Shell w Symfony:
```bash
docker compose exec symfony sh
```

Shell w Phoenix:
```bash
docker compose exec phoenix sh
```

Console Symfony:
```bash
docker compose exec symfony php bin/console
```

Mix w Phoenix:
```bash
docker compose exec phoenix mix help
```

## Jakość kodu

Elixir:
```bash
docker compose exec phoenix mix test
docker compose exec phoenix mix format --check-formatted
docker compose exec phoenix mix credo
docker compose exec phoenix mix dialyzer
```

Symfony:
```bash
docker compose exec symfony composer test
docker compose exec symfony composer phpstan
docker compose exec symfony composer php-cs-fixer
```

## Bazy danych

Porty hosta:
- PostgreSQL Symfony (`php_db`): `localhost:5433`
- PostgreSQL Phoenix (`elixir_db`): `localhost:5434`

Szybkie wejście do bazy:
```bash
docker compose exec php_db psql -U news_php -d news_php
docker compose exec elixir_db psql -U news_elixir -d news_elixir
```

## Migracje

Symfony (Doctrine):
```bash
docker compose exec symfony php bin/console doctrine:migrations:migrate --no-interaction
```

Symfony seeds:
```bash
docker compose exec symfony php bin/console app:seed-news --no-interaction
```

Elixir (`core`):
```bash
docker compose exec phoenix sh -lc 'cd apps/core && mix ecto.migrate'
```

## Elasticsearch / Kibana logi

- Filebeat wysyła logi kontenerów do indeksów `news-logs-*`.
- W Kibanie utwórz Data View: `news-logs-*`.

## Struktura katalogów

- `php/` - aplikacja Symfony
- `elixir/news_umbrella/` - umbrella Phoenix
- `infra/` - Dockerfile i konfiguracje pomocnicze (m.in. filebeat)
- `docker-compose.yml` - stack dev
- `docker-compose.test.yml` - override test/CI
