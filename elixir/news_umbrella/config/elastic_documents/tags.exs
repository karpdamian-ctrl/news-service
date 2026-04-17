import Config

config :core, :elastic_documents,
  tags: %{
    endpoint: "/api/v1/tags",
    index: "tags_v1",
    search_fields: ["name^3", "slug^2"],
    filterable_fields: ["id", "name", "slug"],
    sortable_fields: ["id", "name", "slug", "inserted_at", "updated_at"],
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
