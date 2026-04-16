# News Umbrella

Umbrella zawiera trzy subapki:
- `core` - encje, Ecto schemas, konteksty domenowe i `Core.Repo`
- `feed_generator` - logika generowania/pobierania feedów
- `api` - warstwa HTTP/Phoenix

Uruchomienie z katalogu `elixir/news_umbrella`:

```bash
mix deps.get
mix cmd --app core mix ecto.setup
mix phx.server
```

## Elasticsearch documents

Definicje indeksów/mappingów:
- `config/elastic_documents/*.exs` (jawnie importowane przez `config/elastic_documents.exs`) -> `config :core, :elastic_documents`

Komendy (odpalane z katalogu umbrella):

```bash
mix elastic.reset.all
mix elastic.load.all
mix elastic.reload.all

mix elastic.reset.categories
mix elastic.load.categories
mix elastic.reload.categories

mix elastic.reset.tags
mix elastic.load.tags
mix elastic.reload.tags

mix elastic.reset.media
mix elastic.load.media
mix elastic.reload.media

mix elastic.reset.articles
mix elastic.load.articles
mix elastic.reload.articles

mix elastic.reset.article_revisions
mix elastic.load.article_revisions
mix elastic.reload.article_revisions
```

Automatycznie po `POST/PUT/DELETE` (resources: categories/tags/media/articles) uruchamia się asynchroniczny, inkrementalny sync do Elasticsearch.
