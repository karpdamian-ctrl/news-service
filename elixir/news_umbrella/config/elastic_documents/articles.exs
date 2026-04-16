import Config

config :core, :elastic_documents,
  articles: %{
    endpoint: "/api/v1/articles",
    index: "articles_v1",
    source: {Core.News, :list_articles},
    settings: %{index: %{number_of_shards: 1, number_of_replicas: 0}},
    mappings: %{
      dynamic: "strict",
      properties: %{
        id: %{type: "integer"},
        title: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        slug: %{type: "keyword"},
        description: %{type: "text"},
        content: %{type: "text"},
        status: %{type: "keyword"},
        published_at: %{type: "date"},
        is_breaking: %{type: "boolean"},
        view_count: %{type: "integer"},
        author: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        featured_image_id: %{type: "integer"},
        category_ids: %{type: "integer"},
        category_names: %{type: "keyword"},
        tag_ids: %{type: "integer"},
        tag_names: %{type: "keyword"},
        inserted_at: %{type: "date"},
        updated_at: %{type: "date"}
      }
    }
  }
