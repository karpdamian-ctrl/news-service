import Config

config :core, :elastic_documents,
  categories: %{
    endpoint: "/api/v1/categories",
    index: "categories_v1",
    source: {Core.News, :list_categories},
    settings: %{index: %{number_of_shards: 1, number_of_replicas: 0}},
    mappings: %{
      dynamic: "strict",
      properties: %{
        id: %{type: "integer"},
        name: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        slug: %{type: "keyword"},
        description: %{type: "text"},
        inserted_at: %{type: "date"},
        updated_at: %{type: "date"}
      }
    }
  }
