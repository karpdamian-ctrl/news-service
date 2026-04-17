import Config

config :core, :elastic_documents,
  article_revisions: %{
    endpoint: "/api/v1/article-revisions",
    index: "article_revisions_v1",
    search_fields: ["title^3", "slug^2", "description", "content", "author^2", "changed_by^2", "change_note"],
    filterable_fields: ["id", "article_id", "slug", "status", "author", "changed_by", "featured_image_id"],
    sortable_fields: ["id", "article_id", "title", "slug", "status", "modified_at", "inserted_at"],
    source: {Core.News, :list_article_revisions},
    settings: %{index: %{number_of_shards: 1, number_of_replicas: 0}},
    mappings: %{
      dynamic: "strict",
      properties: %{
        id: %{type: "integer"},
        article_id: %{type: "integer"},
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
        tag_ids: %{type: "integer"},
        modified_at: %{type: "date"},
        change_note: %{type: "text"},
        changed_by: %{type: "text", fields: %{keyword: %{type: "keyword"}}},
        inserted_at: %{type: "date"}
      }
    }
  }
