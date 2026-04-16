defmodule ApiWeb.ArticleRevisionControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Core.News

  describe "article revisions CRUD" do
    setup %{conn: conn} do
      {:ok, article} =
        News.create_article(%{
          title: "Revision Base Article",
          slug: "revision-base-article",
          content: "Base article content long enough for revision tests.",
          status: "draft",
          author: "Editor"
        })

      {:ok, conn: authenticated_conn(conn), article: article}
    end

    test "creates, shows, updates and deletes article revision", %{conn: conn, article: article} do
      create_conn =
        post(conn, "/api/v1/article-revisions", %{
          "article_id" => article.id,
          "changed_by" => "Copy Editor",
          "title" => "Revision V1",
          "description" => "Revision description",
          "content" => "Revision content with enough length for validation.",
          "change_note" => "Grammar fixes"
        })

      assert %{"data" => created} = json_response(create_conn, 201)
      id = created["id"]

      show_conn = get(conn, "/api/v1/article-revisions/#{id}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["article_id"] == article.id

      update_conn =
        put(conn, "/api/v1/article-revisions/#{id}", %{
          "title" => "Revision V2",
          "content" => "Revision content updated with enough length for validation.",
          "changed_by" => "Copy Editor"
        })

      assert %{"data" => updated} = json_response(update_conn, 200)
      assert updated["title"] == "Revision V2"

      delete_conn = delete(conn, "/api/v1/article-revisions/#{id}")
      assert response(delete_conn, 204)
    end

    test "returns 422 for invalid revision payload", %{conn: conn, article: article} do
      conn =
        post(conn, "/api/v1/article-revisions", %{
          "article_id" => article.id,
          "changed_by" => "CE",
          "title" => "Bad",
          "content" => "Too short"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "title")
      assert Map.has_key?(errors, "content")
      assert Map.has_key?(errors, "changed_by")
    end
  end
end
