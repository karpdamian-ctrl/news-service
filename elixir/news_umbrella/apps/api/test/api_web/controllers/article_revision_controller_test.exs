defmodule ApiWeb.ArticleRevisionControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Core.News

  describe "article revisions read-only endpoints" do
    setup %{conn: conn} do
      {:ok, category} = News.create_category(%{name: "Revision", slug: "revision"})
      {:ok, tag} = News.create_tag(%{name: "History", slug: "history"})

      {:ok, article} =
        News.create_article(%{
          title: "Revision Base Article",
          slug: "revision-base-article",
          content: "Base article content long enough for revision tests.",
          status: "draft",
          author: "Editor",
          category_ids: [category.id],
          tag_ids: [tag.id]
        })

      {:ok, _updated_article} =
        News.update_article(article, %{
          "title" => "Revision Base Article Updated",
          "slug" => "revision-base-article-updated",
          "content" => "Updated base article content long enough for revision tests.",
          "status" => "review",
          "author" => "Editor",
          "category_ids" => [category.id],
          "tag_ids" => [tag.id],
          "changed_by" => "Jan Redaktor"
        })

      {:ok, conn: authenticated_conn(conn), article: article}
    end

    test "lists and shows revisions", %{conn: conn, article: article} do
      list_conn =
        get(conn, "/api/v1/article-revisions", %{"filter" => %{"article_id" => article.id}})

      assert %{"data" => revisions} = json_response(list_conn, 200)
      assert length(revisions) >= 1

      [latest | _] = revisions
      assert latest["article_id"] == article.id

      show_conn = get(conn, "/api/v1/article-revisions/#{latest["id"]}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["id"] == latest["id"]
      assert shown["title"] == "Revision Base Article"
      assert shown["slug"] == "revision-base-article"
      assert shown["status"] == "draft"
      assert shown["author"] == "Editor"
      assert shown["changed_by"] == "Jan Redaktor"
      assert is_binary(shown["modified_at"])
    end

    test "returns 404 for write methods", %{conn: conn, article: article} do
      conn = Plug.Conn.put_req_header(conn, "accept", "application/json")

      post_conn =
        post(conn, "/api/v1/article-revisions", %{
          "article_id" => article.id,
          "changed_by" => "Copy Editor",
          "title" => "Revision V1",
          "slug" => "revision-v1",
          "content" => "Revision content with enough length for validation.",
          "status" => "draft",
          "author" => "Copy Editor"
        })

      assert %{"errors" => %{"detail" => "Not Found"}} = json_response(post_conn, 404)

      put_conn =
        put(conn, "/api/v1/article-revisions/1", %{
          "title" => "Revision V2",
          "slug" => "revision-v2",
          "content" => "Revision content updated with enough length for validation.",
          "status" => "review",
          "author" => "Copy Editor",
          "changed_by" => "Copy Editor"
        })

      assert %{"errors" => %{"detail" => "Not Found"}} = json_response(put_conn, 404)

      delete_conn = delete(conn, "/api/v1/article-revisions/1")
      assert %{"errors" => %{"detail" => "Not Found"}} = json_response(delete_conn, 404)
    end
  end
end
