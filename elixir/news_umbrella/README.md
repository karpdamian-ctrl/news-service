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
