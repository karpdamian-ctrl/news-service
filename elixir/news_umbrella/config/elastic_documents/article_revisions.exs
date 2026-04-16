import Config

config :core, :elastic_documents,
  article_revisions: %{
    endpoint: "/api/v1/article-revisions",
    index: "article_revisions_v1",
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
