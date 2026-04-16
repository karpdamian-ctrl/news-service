defmodule ApiWeb.ArticleControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Core.News

  describe "articles list params" do
    setup %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, c1} = News.create_category(%{name: "AI", slug: "ai"})
      {:ok, c2} = News.create_category(%{name: "Sport", slug: "sport"})

      {:ok, t1} = News.create_tag(%{name: "LLM", slug: "llm"})
      {:ok, _t2} = News.create_tag(%{name: "Football", slug: "football"})

      {:ok, _a1} =
        News.create_article(%{
          title: "AI Alpha",
          slug: "ai-alpha",
          description: "first",
          content: "AI alpha article content for pagination and filtering tests.",
          status: "published",
          published_at: now,
          author: "Author A",
          category_ids: [c1.id],
          tag_ids: [t1.id],
          view_count: 5,
          is_breaking: false
        })

      {:ok, _a2} =
        News.create_article(%{
          title: "AI Zeta",
          slug: "ai-zeta",
          description: "second",
          content: "AI zeta article content for pagination and filtering tests.",
          status: "published",
          published_at: now,
          author: "Author B",
          category_ids: [c1.id],
          tag_ids: [t1.id],
          view_count: 20,
          is_breaking: true
        })

      {:ok, _a3} =
        News.create_article(%{
          title: "Sports Bulletin",
          slug: "sports-daily",
          description: "third",
          content: "Sports bulletin article content for pagination and filtering tests.",
          status: "draft",
          author: "Author C",
          category_ids: [c2.id],
          view_count: 2,
          is_breaking: false
        })

      {:ok, conn: authenticated_conn(conn)}
    end

    test "supports page/per_page/sort/order/filter/q", %{conn: conn} do
      conn =
        get(conn, "/api/v1/articles", %{
          "page" => "1",
          "per_page" => "2",
          "sort" => "title",
          "order" => "asc",
          "q" => "AI",
          "filter" => %{"status" => "published"}
        })

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)

      assert meta["page"] == 1
      assert meta["per_page"] == 2
      assert meta["total_count"] == 2
      assert meta["total_pages"] == 1
      assert meta["sort"] == "title"
      assert meta["order"] == "asc"
      assert meta["has_prev_page"] == false
      assert meta["has_next_page"] == false

      assert Enum.map(data, & &1["title"]) == ["AI Alpha", "AI Zeta"]
    end

    test "returns 400 for invalid sort field", %{conn: conn} do
      conn = get(conn, "/api/v1/articles?sort=__invalid__")

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "article relations" do
    setup %{conn: conn} do
      {:ok, category} = News.create_category(%{name: "Tech", slug: "tech"})
      {:ok, tag} = News.create_tag(%{name: "API", slug: "api"})

      {:ok, conn: authenticated_conn(conn), category: category, tag: tag}
    end

    test "creates article with category_ids/tag_ids and returns them in response", %{
      conn: conn,
      category: category,
      tag: tag
    } do
      payload = %{
        "title" => "Linked article",
        "slug" => "linked-article",
        "description" => "desc",
        "content" => "Linked article content with enough length for validation.",
        "status" => "draft",
        "author" => "Editor",
        "category_ids" => [category.id],
        "tag_ids" => [tag.id]
      }

      conn = post(conn, "/api/v1/articles", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["category_ids"] == [category.id]
      assert data["tag_ids"] == [tag.id]
    end

    test "returns 422 when category_ids or tag_ids contain unknown ids", %{conn: conn} do
      payload = %{
        "title" => "Invalid relations article",
        "slug" => "invalid-relations-article",
        "description" => "desc",
        "content" => "Linked article content with enough length for validation.",
        "status" => "draft",
        "author" => "Editor",
        "category_ids" => [999_999],
        "tag_ids" => [999_998]
      }

      conn = post(conn, "/api/v1/articles", payload)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "category_ids")
      assert Map.has_key?(errors, "tag_ids")
    end
  end

  describe "articles CRUD" do
    setup %{conn: conn} do
      {:ok, category} = News.create_category(%{name: "Tech", slug: "tech"})
      {:ok, tag} = News.create_tag(%{name: "Cloud", slug: "cloud"})

      {:ok, media} =
        News.create_media(%{
          type: "image",
          path: "/uploads/news/article-cover.jpg",
          mime_type: "image/jpeg",
          uploaded_by: "Editor"
        })

      {:ok, conn: authenticated_conn(conn), category: category, tag: tag, media: media}
    end

    test "creates, shows, updates and deletes article", %{
      conn: conn,
      category: category,
      tag: tag,
      media: media
    } do
      create_payload = %{
        "title" => "Cloud Market Outlook",
        "slug" => "cloud-market-outlook",
        "description" => "Initial description",
        "content" => "Long article content for CRUD tests with enough characters.",
        "status" => "published",
        "published_at" => "2026-04-16T12:00:00Z",
        "author" => "Jane Reporter",
        "featured_image_id" => media.id,
        "category_ids" => [category.id],
        "tag_ids" => [tag.id]
      }

      create_conn = post(conn, "/api/v1/articles", create_payload)
      assert %{"data" => created} = json_response(create_conn, 201)
      id = created["id"]
      assert created["category_ids"] == [category.id]
      assert created["tag_ids"] == [tag.id]

      show_conn = get(conn, "/api/v1/articles/#{id}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["slug"] == "cloud-market-outlook"

      update_conn =
        put(conn, "/api/v1/articles/#{id}", %{
          "title" => "Cloud Market Outlook Updated",
          "slug" => "cloud-market-outlook-updated",
          "content" => "Updated long article content for CRUD tests with enough characters.",
          "status" => "draft",
          "author" => "Jane Reporter"
        })

      assert %{"data" => updated} = json_response(update_conn, 200)
      assert updated["title"] == "Cloud Market Outlook Updated"
      assert updated["status"] == "draft"

      delete_conn = delete(conn, "/api/v1/articles/#{id}")
      assert response(delete_conn, 204)
    end

    test "returns 422 when published article has no published_at", %{conn: conn} do
      conn =
        post(conn, "/api/v1/articles", %{
          "title" => "Invalid Published",
          "slug" => "invalid-published",
          "content" => "Long enough content to trigger published_at validation on create.",
          "status" => "published",
          "author" => "Editor"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "published_at")
    end
  end
end
