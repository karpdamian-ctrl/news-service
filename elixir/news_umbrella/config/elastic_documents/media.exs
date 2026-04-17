import Config

config :core, :elastic_documents,
  media: %{
    endpoint: "/api/v1/media",
    index: "media_v1",
    search_fields: ["path^3", "alt_text^2", "caption", "uploaded_by", "mime_type"],
    filterable_fields: ["id", "type", "mime_type", "uploaded_by"],
    sortable_fields: ["id", "type", "size_bytes", "inserted_at"],
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
