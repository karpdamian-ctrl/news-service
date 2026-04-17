import Config

config :core, :elastic_documents,
  categories: %{
    endpoint: "/api/v1/categories",
    index: "categories_v1",
    search_fields: ["name^3", "slug^2", "description"],
    filterable_fields: ["id", "name", "slug"],
    sortable_fields: ["id", "name", "slug", "inserted_at", "updated_at"],
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
