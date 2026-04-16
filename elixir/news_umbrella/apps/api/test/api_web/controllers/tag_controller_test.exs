defmodule ApiWeb.TagControllerTest do
  use ApiWeb.ConnCase, async: true

  describe "tags CRUD" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "creates, shows, updates and deletes tag", %{conn: conn} do
      create_conn =
        post(conn, "/api/v1/tags", %{
          "name" => "Economy",
          "slug" => "economy"
        })

      assert %{"data" => created} = json_response(create_conn, 201)
      id = created["id"]

      show_conn = get(conn, "/api/v1/tags/#{id}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["slug"] == "economy"

      update_conn =
        put(conn, "/api/v1/tags/#{id}", %{
          "name" => "Macro Economy",
          "slug" => "macro-economy"
        })

      assert %{"data" => updated} = json_response(update_conn, 200)
      assert updated["name"] == "Macro Economy"

      delete_conn = delete(conn, "/api/v1/tags/#{id}")
      assert response(delete_conn, 204)
    end

    test "returns 422 for invalid slug format", %{conn: conn} do
      conn =
        post(conn, "/api/v1/tags", %{
          "name" => "Bad Tag",
          "slug" => "Bad Slug!"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "slug")
    end
  end
end
