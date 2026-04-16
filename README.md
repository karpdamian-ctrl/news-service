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

Uwaga: `down -v` usuwa też dane Elasticsearch/Kibana (dashboardy, saved searches, data views).

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
- Symfony Profiler: http://localhost:8080/_profiler/
- Phoenix: http://localhost:4000
- Elixir API: http://localhost:4000/api/v1
- Redis Commander: http://localhost:8081
- RabbitMQ Management: http://localhost:15672
- Kibana: http://localhost:5601
- Elasticsearch API: http://localhost:9200

Trwałość ustawień Kibany:
- dashboardy i zapisane wyszukiwania są przechowywane w Elasticsearch (indeks `.kibana*`)
- dodatkowo stan Kibany jest trzymany w wolumenie `kibana_data`
- rekreacja kontenerów (`up --force-recreate`) nie usuwa tych danych
- dane znikną dopiero po `docker compose down -v` lub ręcznym usunięciu wolumenów

## Dane aplikacji

Aktualnie source of truth dla danych newsowych jest po stronie Elixira (`apps/core` + `Core.Repo`).
API CRUD dla encji jest wystawione w Phoenix (`apps/api`) pod `/api/v1/*`.
API nie ma już obsługi panelu admina/użytkowników; autoryzacja to prosty token.

## Loginy / hasła

RabbitMQ Management:
- login: `news`
- hasło: `news`

Elixir API token:
- (trzymany w `elixir/news_umbrella/config/config.exs`): `news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0`

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

Symfony debug toolbar:
- dziala w `APP_ENV=dev` (aktualnie ustawione w `docker-compose.yml`)
- po wejsciu na dowolna strone Symfony na dole zobaczysz pasek debug
- szczegoly requestu: `http://localhost:8080/_profiler/`

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

Pliki publiczne (media):
- katalog na hostcie: `public/uploads/news/`
- publiczny URL: `http://localhost:4000/uploads/news/<nazwa-pliku>`

## API (Phoenix / JSON)

Base URL:
```bash
http://localhost:4000/api/v1
```

Dostępne endpointy CRUD:
- `GET/POST /api/v1/categories`
- `GET/PUT/DELETE /api/v1/categories/:id`
- `GET/POST /api/v1/tags`
- `GET/PUT/DELETE /api/v1/tags/:id`
- `GET/POST /api/v1/media`
- `GET/PUT/DELETE /api/v1/media/:id`
- `GET/POST /api/v1/articles`
- `GET/PUT/DELETE /api/v1/articles/:id`
- `GET/POST /api/v1/article-revisions`
- `GET/PUT/DELETE /api/v1/article-revisions/:id`

Autoryzacja:
- nagłówek `Authorization: Bearer <token>` lub `x-api-token: <token>`
- bez tokenu API zwraca `401 {"error":"unauthorized"}`

Standardowe parametry listowania (`GET` na kolekcjach):
- `page` (domyślnie `1`)
- `per_page` (domyślnie `20`, max `100`)
- `sort` (pole sortowania, zależne od zasobu)
- `order` (`asc` lub `desc`)
- `q` (wyszukiwanie tekstowe po polach danego zasobu)
- `filter[field]=value` (filtrowanie po dozwolonych polach)

Przykład:
```bash
curl -G http://localhost:4000/api/v1/articles \
  -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" \
  --data-urlencode "page=1" \
  --data-urlencode "per_page=10" \
  --data-urlencode "sort=published_at" \
  --data-urlencode "order=desc" \
  --data-urlencode "q=ai" \
  --data-urlencode "filter[status]=published"
```

Każda lista zwraca:
- `data` (rekordy)
- `meta` (`page`, `per_page`, `total_count`, `total_pages`, `sort`, `order`, `has_prev_page`, `has_next_page`)

Dozwolone pola `sort` / `filter`:
- `categories`: sort `id,name,slug,inserted_at,updated_at`; filter `name,slug`
- `tags`: sort `id,name,slug,inserted_at,updated_at`; filter `name,slug`
- `media`: sort `id,type,path,size_bytes,inserted_at`; filter `type,mime_type,uploaded_by`
- `articles`: sort `id,title,slug,status,published_at,view_count,inserted_at,updated_at`; filter `title,slug,status,author,is_breaking`
- `article-revisions`: sort `id,title,article_id,changed_by,inserted_at`; filter `title,article_id,changed_by`

Przykładowy flow:

1. Utwórz kategorię:
```bash
curl -X POST http://localhost:4000/api/v1/categories \
  -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Technology",
    "slug": "technology",
    "description": "Tech news"
  }'
```

2. Utwórz tag:
```bash
curl -X POST http://localhost:4000/api/v1/tags \
  -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AI",
    "slug": "ai"
  }'
```

3. Utwórz artykuł (z relacjami):
```bash
curl -X POST http://localhost:4000/api/v1/articles \
  -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Nowy model AI",
    "slug": "nowy-model-ai",
    "description": "Krótki opis",
    "content": "Pełna treść artykułu",
    "status": "published",
    "published_at": "2026-04-16T12:00:00Z",
    "author": "Jan Kowalski",
    "category_ids": [1],
    "tag_ids": [1],
    "is_breaking": false
  }'
```

4. Dodaj rewizję artykułu:
```bash
curl -X POST http://localhost:4000/api/v1/article-revisions \
  -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" \
  -H "Content-Type: application/json" \
  -d '{
    "article_id": 1,
    "changed_by": "Redakcja",
    "title": "Nowy model AI",
    "description": "Opis po korekcie",
    "content": "Treść po korekcie",
    "change_note": "Korekta redakcyjna"
  }'
```

5. Pobieranie listy:
```bash
curl -H "Authorization: Bearer news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0" http://localhost:4000/api/v1/articles
```

## Elasticsearch / Kibana logi

- Filebeat wysyła logi kontenerów do indeksów `news-logs-*`.
- W Kibanie utwórz Data View: `news-logs-*`.
- Operacje API Elixira są logowane jako wpisy `API_AUDIT ...` (JSON w `message`).
- Przykładowy filtr w Kibanie (KQL): `container.name : "news_phoenix" and message : "API_AUDIT"`.

## Struktura katalogów

- `php/` - aplikacja Symfony
- `elixir/news_umbrella/` - umbrella Phoenix
- `infra/` - Dockerfile i konfiguracje pomocnicze (m.in. filebeat)
- `docker-compose.yml` - stack dev
- `docker-compose.test.yml` - override test/CI
