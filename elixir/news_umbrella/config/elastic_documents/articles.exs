import Config

config :core, :elastic_documents,
  articles: %{
    endpoint: "/api/v1/articles",
    index: "articles_v1",
    search_fields: ["title^4", "slug^3", "description^2", "content", "author^2", "category_names^2", "tag_names^2"],
    filterable_fields: ["id", "slug", "status", "author", "is_breaking", "featured_image_id", "category_ids", "tag_ids"],
    sortable_fields: ["id", "title", "slug", "status", "published_at", "view_count", "inserted_at", "updated_at"],
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
        content_html: %{type: "text", index: false},
        status: %{type: "keyword"},
        published_at: %{type: "date"},
        is_breaking: %{type: "boolean"},
        view_count: %{type: "integer"},
        author: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        featured_image_id: %{type: "integer"},
        category_ids: %{type: "integer"},
        category_names: %{type: "keyword"},
        category_refs: %{type: "keyword"},
        tag_ids: %{type: "integer"},
        tag_names: %{type: "keyword"},
        tag_refs: %{type: "keyword"},
        inserted_at: %{type: "date"},
        updated_at: %{type: "date"}
      }
    }
  }
