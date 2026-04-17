# News Platform (Dev/Test)

## O projekcie

To jest projekt typu zabawa / playground.
Nie musi mieć ścisłego sensu biznesowego - celem było praktyczne sprawdzenie i połączenie wielu narzędzi w jednym środowisku.

Najciekawsze elementy wykorzystane w projekcie:
- Elixir + Phoenix Umbrella (API + subapki)
- Symfony (panel adminowy + frontend)
- PostgreSQL (osobne bazy dla PHP i Elixira)
- Redis (scheduler, rate limit)
- RabbitMQ (kolejki i asynchroniczne przetwarzanie)
- Elasticsearch + Kibana (wyszukiwanie i obserwowalność)
- Filebeat (zbieranie i filtrowanie logów)
- Docker Compose (spójne środowisko lokalne)

Projekt portfolio oparty o mikroserwisy:
- `symfony` (PHP panel adminowy działający przez Elixir API)
- `phoenix` (Elixir/Phoenix umbrella)
- `core` (subapka Elixir odpowiedzialna za warstwę danych / Repo)
- osobne PostgreSQL: `php_db` i `elixir_db`
- Redis + Redis Commander
- RabbitMQ + RabbitMQ Management
- Elasticsearch + Kibana + Filebeat (zbieranie logów kontenerów)

## Schemat aplikacji

```mermaid
flowchart LR
    U[Użytkownik / przeglądarka]

    subgraph PHP["Symfony (php)"]
      H[Frontend publiczny]
      A[Panel admin]
      UA[(PostgreSQL php_db<br/>users)]
    end

    subgraph ELX["Elixir Umbrella (phoenix)"]
      API[API /api/v1]
      CORE[Core domain + Repo]
      AG[articles_generator]
      RL[Rate limiter]
      CR[Markdown -> HTML consumer]
      EDB[(PostgreSQL elixir_db<br/>news data)]
    end

    subgraph INFRA["Infra"]
      R[(Redis)]
      Q[(RabbitMQ)]
      ES[(Elasticsearch)]
      KB[Kibana]
      FB[Filebeat]
    end

    U --> H
    U --> A

    H -->|REST| API
    A -->|REST CRUD| API
    A --> UA

    API --> CORE
    CORE --> EDB

    API --> RL
    RL --> R

    AG --> R
    AG --> CORE

    CORE -->|publish render job| Q
    Q --> CR
    CR --> CORE

    CORE -->|index/search| ES
    H -->|search endpoints| ES

    API -->|logs| FB
    H -->|logs| FB
    A -->|logs| FB
    FB --> ES
    KB --> ES
```

## Wymagania

- Docker + Docker Compose
- Linux/Ubuntu: uruchamiaj z `LOCAL_UID` i `LOCAL_GID`, żeby nie mieszać uprawnień plików.

## Start (DEV)

```bash
LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose up -d --build --force-recreate
```

### Pierwsze uruchomienie po czyszczeniu danych

Po starcie kontenerów wykonaj inicjalizację w tej kolejności:

1. Utwórz/reutwórz indeksy Elasticsearch na podstawie definicji (mapping + settings):
```bash
docker compose exec phoenix sh -lc 'cd /app && mix elastic.reset.all'
```

2. Załaduj seedy do bazy Elixira:
```bash
docker compose exec phoenix sh -lc 'cd /app/apps/core && mix run priv/repo/seeds.exs'
```

Seedy zapisują dane do PostgreSQL i jednocześnie publikują eventy, więc dokumenty są automatycznie indeksowane w Elasticsearch.

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

Uwaga (Phoenix + `mix`):
- kontener `phoenix` ma rozdzielone build path:
  - serwer: `/tmp/news_mix_server`
  - komendy uruchamiane przez `docker compose exec phoenix ...`: `/tmp/news_mix_cli`
- dzięki temu ręczne `mix` (np. seedy, elastic tasks) nie rozwalają CodeReloadera i nie powodują błędu `compile.lock changed`.

## Adresy i panele

- Symfony: http://localhost:8080
- Symfony Frontend Home: http://localhost:8080/
- Symfony Frontend Category: http://localhost:8080/category/<slug>
- Symfony Frontend Tag: http://localhost:8080/tag/<slug>
- Symfony login: http://localhost:8080/login
- Symfony Admin Panel: http://localhost:8080/admin
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

Source of truth dla danych newsowych jest po stronie Elixira (`apps/core` + `Core.Repo`).
Panel adminowy w Symfony wykonuje CRUD wyłącznie przez Elixir API (`/api/v1/*`) i nie używa encji Doctrine dla newsów.
Autoryzacja API to prosty token.
Frontend użytkownika w Symfony pobiera dane list/hero/category/tag przez endpointy `*/search` (Elasticsearch), a strona pojedynczego artykułu (`/article/<slug>`) korzysta z endpointu bazodanowego `GET /api/v1/articles`.

Użytkownicy są wyjątkiem:
- konta panelowe (`users`) są utrzymywane po stronie Symfony/Doctrine (baza `php_db`)
- dane newsowe (`articles`, `categories`, `tags`, `media`, `revisions`) są utrzymywane po stronie Elixira (baza `elixir_db`)

Dlaczego to ma sens w tym projekcie:
- Symfony odpowiada za panel i sesyjne logowanie użytkowników, więc lokalny model `User` upraszcza security i role.
- Elixir pozostaje jednym źródłem prawdy dla domeny newsowej i API.
- rozdział odpowiedzialności jest czytelny: IAM/admin login w PHP, content domain w Elixirze.

Trade-off:
- to jest architektura polyglot z dwoma bazami, więc wymaga pilnowania granic domenowych i braku cross-write między systemami.

## API rate limit (Elixir)

W API działa mechanizm rate limitu oparty o Redis:
- limit: `60` zapytań na `60` sekund na klienta (IP / `x-forwarded-for`)
- po przekroczeniu API zwraca `429` + nagłówek `retry-after`
- odpowiedź JSON: `error=rate_limited` i komunikat o przekroczeniu limitu
- klucze Redis są trzymane pod prefixem `api_rate_limit:*` z TTL 60 sekund
- przekroczenia limitu są logowane jako warning (`API_RATE_LIMIT_EXCEEDED`)

## Generator artykułów (Elixir + Redis)

W umbrelli działa osobna subapka `articles_generator`, uruchamiana razem z `phoenix`.
Generator działa cyklicznie na `GenServer` i tworzy nowy artykuł w losowym odstępie czasu między 3 a 6 minut.

Sprzężenie z Redisem:
- harmonogram następnej publikacji jest trzymany w Redis pod kluczem `articles_generator:next_generation_at`
- wartość klucza to unix timestamp (sekundy)
- po starcie generator odczytuje ten klucz; jeśli go nie ma, ustawia nowy termin
- po wygenerowaniu artykułu generator zapisuje kolejny termin do tego samego klucza

Logi generatora:
- `ARTICLE_GENERATOR_NEXT` - zaplanowano kolejny termin
- `ARTICLE_GENERATOR_CREATED` - artykuł został wygenerowany
- `ARTICLE_GENERATOR_SKIPPED` / `ARTICLE_GENERATOR_REDIS_ERROR` - pominięcie lub błąd Redis

Szybka weryfikacja:
```bash
# podgląd logów generatora
docker compose logs -f phoenix | rg "ARTICLE_GENERATOR|articles_generator"

# odczyt najbliższego terminu z Redis
docker compose exec redis redis-cli GET articles_generator:next_generation_at
```

## Render markdown -> HTML (Core + RabbitMQ)

W `core` działa asynchroniczny pipeline renderowania treści artykułów:
- po `create/update` artykułu publikowana jest wiadomość do kolejki RabbitMQ `news.article_markdown.render`
- konsument `Core.ContentRenderer.QueueConsumer` odbiera zadania i renderuje markdown do HTML
- wynik zapisywany jest w nowym polu `articles.content_html`
- strona artykułu na froncie Symfony renderuje właśnie `content_html` (z fallbackiem do `content`, gdy HTML nie jest jeszcze gotowy)
- podczas uruchamiania seedów `core` HTML jest też generowany od razu dla każdego seeded artykułu

Dlaczego to ma sens:
- zapis artykułu w API jest szybki (render nie blokuje requestu)
- render można skalować niezależnie (więcej konsumentów)
- łatwiej dodać kolejne etapy przetwarzania (sanityzacja, ekstrakcja snippetów, itp.)

Konfiguracja:
- `config/config.exs`
  - `:article_render_queue_publisher_module`
  - `Core.ContentRenderer.QueueConsumer` (`enabled`, `queue`, `reconnect_ms`)
- w `test` konsument jest wyłączony i publisher jest `Noop`, więc testy nie wymagają RabbitMQ

## Loginy / hasła

RabbitMQ Management:
- login: `news`
- hasło: `news`

Elixir API token:
- (trzymany w `elixir/news_umbrella/config/config.exs`): `news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0`

Panel Symfony (seed do bazy `users`):
- admin: `admin@news.local` / `admin123`
- redactor: `redactor@news.local` / `redactor123`

Pozostałe panele są w dev bez dodatkowego logowania.

## Komendy (PHP i Elixir)

Podstawowe wejście do kontenerów:
```bash
docker compose exec symfony sh
docker compose exec phoenix sh
```

### PHP (Symfony)

Console:
```bash
docker compose exec symfony php bin/console
```

Migracje:
```bash
docker compose exec symfony php bin/console doctrine:migrations:migrate --no-interaction
```

Seed użytkowników (admin + redactor):
```bash
docker compose exec symfony php bin/console app:seed-users --no-interaction
```

Jakość kodu / testy:
```bash
docker compose exec symfony composer test
docker compose exec symfony composer phpstan
docker compose exec symfony composer php-cs-fixer
```

### Elixir (Phoenix umbrella)

Mix:
```bash
docker compose exec phoenix mix help
```

Migracje `core`:
```bash
docker compose exec phoenix sh -lc 'cd apps/core && mix ecto.migrate'
```

Seedy `core`:
```bash
docker compose exec phoenix sh -lc 'cd apps/core && mix run priv/repo/seeds.exs'
```

Wrzuć wszystkie artykuły do kolejki przegenerowania markdown -> HTML:
```bash
docker compose exec phoenix sh -lc 'cd apps/core && mix content.render.enqueue_all'
```

Przeładowanie seedów `core` (drop + create + migrate + seeds):
```bash
docker compose exec phoenix sh -lc 'cd apps/core && mix ecto.reset'
```

Jakość kodu / testy:
```bash
docker compose exec phoenix mix test
docker compose exec phoenix mix test.integration
docker compose exec phoenix mix format --check-formatted
docker compose exec phoenix mix credo
docker compose exec phoenix mix dialyzer
```

`mix test` pomija testy integracyjne (`@moduletag :integration`), a `mix test.integration` uruchamia tylko je.

Elasticsearch (definicje + indeksowanie dokumentów):
- definicje indeksów i mappingów: `elixir/news_umbrella/config/elastic_documents/*.exs` (jawnie importowane w `elixir/news_umbrella/config/elastic_documents.exs`)
- osobne komendy per endpoint:

```bash
# wszystko naraz
docker compose exec phoenix mix elastic.reset.all
docker compose exec phoenix mix elastic.load.all
docker compose exec phoenix mix elastic.reload.all

# categories
docker compose exec phoenix mix elastic.reset.categories
docker compose exec phoenix mix elastic.load.categories
docker compose exec phoenix mix elastic.reload.categories

# tags
docker compose exec phoenix mix elastic.reset.tags
docker compose exec phoenix mix elastic.load.tags
docker compose exec phoenix mix elastic.reload.tags

# media
docker compose exec phoenix mix elastic.reset.media
docker compose exec phoenix mix elastic.load.media
docker compose exec phoenix mix elastic.reload.media

# articles
docker compose exec phoenix mix elastic.reset.articles
docker compose exec phoenix mix elastic.load.articles
docker compose exec phoenix mix elastic.reload.articles

# article-revisions
docker compose exec phoenix mix elastic.reset.article_revisions
docker compose exec phoenix mix elastic.load.article_revisions
docker compose exec phoenix mix elastic.reload.article_revisions
```

Typowy flow:
1. `elastic.reset.<resource>` - usuwa i tworzy indeks od nowa (settings + mappings)
2. `elastic.load.<resource>` - ładuje dane z Postgresa do Elasticsearch
3. `elastic.reload.<resource>` - krok 1 + krok 2 w jednej komendzie

Automatyczna synchronizacja indeksów:
- po `POST/PUT/DELETE` na API (`categories`, `tags`, `media`, `articles`) indeksy odświeżają się automatycznie
- działa asynchronicznie przez event worker (nie blokuje requestu API)
- synchronizacja jest inkrementalna (`upsert/delete` pojedynczych dokumentów + reindeks powiązanych artykułów/rewizji gdy to konieczne)

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
- `GET /api/v1/categories/search`
- `GET /api/v1/categories/popular?limit=5` (top kategorie wg częstotliwości w indeksie `articles_v1`)
- `GET/POST /api/v1/tags`
- `GET/PUT/DELETE /api/v1/tags/:id`
- `GET /api/v1/tags/search`
- `GET/POST /api/v1/media`
- `GET/PUT/DELETE /api/v1/media/:id`
- `GET /api/v1/media/search`
- `GET/POST /api/v1/articles`
- `GET/PUT/DELETE /api/v1/articles/:id`
- `POST /api/v1/articles/:id/view` (inkrementacja licznika wyświetleń)
- `GET /api/v1/articles/search`
- `GET/POST /api/v1/article-revisions`
- `GET/PUT/DELETE /api/v1/article-revisions/:id`
- `GET /api/v1/article-revisions/search`

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

Parametry dla endpointów `*/search` (Elasticsearch):
- `q` (full-text query; gdy puste -> `match_all`)
- `page` i `per_page` (paginacja; `per_page` max `100`)
- `sort` i `order` (sortowanie po polach dozwolonych w definicji indeksu)
- `filter[field]=value` (term/terms filters po polach dozwolonych)

`/search` zwraca bezpośrednio dokumenty z Elasticsearch (`data` + `meta`), bez dodatkowego dociągania rekordów z Postgresa.

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
- Operacje aktualizacji użytkowników w Symfony są logowane jako wpisy `USER_AUDIT ...` (JSON w `message`).
- Przykładowy filtr w Kibanie (KQL): `container.name : "news_phoenix" and message : "API_AUDIT"`.
- Przykładowy filtr dla Symfony users audit (KQL): `container.name : "news_symfony" and message : "USER_AUDIT"`.

## Struktura katalogów

- `php/` - aplikacja Symfony
- `elixir/news_umbrella/` - umbrella Phoenix
- `infra/` - Dockerfile i konfiguracje pomocnicze (m.in. filebeat)
- `docker-compose.yml` - stack dev
- `docker-compose.test.yml` - override test/CI
