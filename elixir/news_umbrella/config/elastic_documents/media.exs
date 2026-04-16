import Config

config :core, :elastic_documents,
  media: %{
    endpoint: "/api/v1/media",
    index: "media_v1",
    source: {Core.News, :list_media},
    settings: %{index: %{number_of_shards: 1, number_of_replicas: 0}},
    mappings: %{
      dynamic: "strict",
      properties: %{
        id: %{type: "integer"},
        type: %{type: "keyword"},
        path: %{type: "keyword"},
        mime_type: %{type: "keyword"},
        size_bytes: %{type: "integer"},
        alt_text: %{type: "text"},
        caption: %{type: "text"},
        uploaded_by: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        inserted_at: %{type: "date"}
      }
    }
  }
