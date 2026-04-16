import Config

config :core, :elastic_documents,
  tags: %{
    endpoint: "/api/v1/tags",
    index: "tags_v1",
    source: {Core.News, :list_tags},
    settings: %{index: %{number_of_shards: 1, number_of_replicas: 0}},
    mappings: %{
      dynamic: "strict",
      properties: %{
        id: %{type: "integer"},
        name: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        slug: %{type: "keyword"},
        inserted_at: %{type: "date"},
        updated_at: %{type: "date"}
      }
    }
  }
