defmodule Core.News.SearchSyncTest do
  use Core.DataCase, async: false

  alias Core.News
  alias Core.News.{Article, Tag}

  defmodule FakePublisher do
    def publish(event) do
      send(self(), {:search_event, event})
      :ok
    end
  end

  setup do
    previous = Application.get_env(:core, :search_events_module)
    Application.put_env(:core, :search_events_module, FakePublisher)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:core, :search_events_module)
      else
        Application.put_env(:core, :search_events_module, previous)
      end
    end)

    :ok
  end

  test "create/update/delete tag publishes search sync events" do
    {:ok, tag} = News.create_tag(%{name: "SearchTag", slug: "search-tag"})
    tag_id = tag.id
    assert_received {:search_event, {:upsert, :tags, %Tag{id: ^tag_id}}}

    {:ok, category} = create_category("sync-tag-category")
    {:ok, article} = create_article(category.id, tag.id, nil, "sync-tag-article")

    {:ok, updated_tag} = News.update_tag(tag, %{name: "SearchTag Updated", slug: "search-tag"})
    updated_tag_id = updated_tag.id
    assert_received {:search_event, {:upsert, :tags, %Tag{id: ^updated_tag_id}}}
    assert_received {:search_event, {:reindex_articles, ids}}
    assert article.id in ids

    {:ok, _} = News.delete_tag(updated_tag)
    assert_received {:search_event, {:delete, :tags, id}}
    assert id == updated_tag_id
    assert_received {:search_event, {:reindex_articles, ids_after_delete}}
    assert article.id in ids_after_delete
  end

  test "update article publishes revision and article upsert events" do
    {:ok, category} = create_category("sync-article-category")
    {:ok, tag} = create_tag("sync-article-tag")
    {:ok, media} = create_media("sync-article-media.jpg")
    {:ok, article} = create_article(category.id, tag.id, media.id, "sync-article")

    flush_events()

    {:ok, updated_article} =
      News.update_article(article, %{
        "title" => "Sync Article Updated",
        "slug" => "sync-article",
        "description" => "Updated description",
        "content" => "Updated content that has enough length for validations.",
        "status" => "published",
        "author" => "Editorial Team",
        "published_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "category_ids" => [category.id],
        "tag_ids" => [tag.id],
        "featured_image_id" => media.id,
        "changed_by" => "Editor Name"
      })

    updated_article_id = updated_article.id
    assert_received {:search_event, {:upsert, :article_revisions, revision}}
    assert revision.article_id == updated_article_id
    assert revision.changed_by == "Editor Name"

    assert_received {:search_event, {:upsert, :articles, %Article{id: ^updated_article_id}}}
  end

  test "delete media publishes delete event and dependent reindex events" do
    {:ok, category} = create_category("sync-media-category")
    {:ok, tag} = create_tag("sync-media-tag")
    {:ok, media} = create_media("sync-media.jpg")
    {:ok, article} = create_article(category.id, tag.id, media.id, "sync-media-article")

    {:ok, _updated_article} =
      News.update_article(article, %{
        "title" => "Sync Media Article Updated",
        "slug" => "sync-media-article",
        "description" => "Desc",
        "content" => "Updated content that has enough length for validations.",
        "status" => "draft",
        "author" => "Editorial Team",
        "category_ids" => [category.id],
        "tag_ids" => [tag.id],
        "featured_image_id" => media.id,
        "changed_by" => "Editor Name"
      })

    flush_events()

    {:ok, _} = News.delete_media(media)

    assert_received {:search_event, {:delete, :media, deleted_media_id}}
    assert deleted_media_id == media.id

    assert_received {:search_event, {:reindex_articles, article_ids}}
    assert article.id in article_ids

    assert_received {:search_event, {:reindex_article_revisions, revision_ids}}
    assert length(revision_ids) >= 1
  end

  defp create_category(slug_suffix) do
    News.create_category(%{
      name: "Category #{slug_suffix}",
      slug: "category-#{slug_suffix}",
      description: "Category description"
    })
  end

  defp create_tag(slug_suffix) do
    News.create_tag(%{
      name: "Tag #{slug_suffix}",
      slug: "tag-#{slug_suffix}"
    })
  end

  defp create_media(filename) do
    News.create_media(%{
      type: "image",
      path: "/uploads/news/#{filename}",
      mime_type: "image/jpeg",
      size_bytes: 100_000,
      alt_text: "Alt",
      caption: "Caption",
      uploaded_by: "Uploader Name"
    })
  end

  defp create_article(category_id, tag_id, featured_image_id, slug_suffix) do
    News.create_article(%{
      title: "Article #{slug_suffix}",
      slug: "article-#{slug_suffix}",
      description: "Description",
      content: "This is a sufficiently long article content for validation checks.",
      status: "draft",
      author: "Author Name",
      featured_image_id: featured_image_id,
      category_ids: [category_id],
      tag_ids: [tag_id]
    })
  end

  defp flush_events do
    receive do
      {:search_event, _} -> flush_events()
    after
      0 -> :ok
    end
  end
end
