defmodule ApiWeb.CategoryControllerTest do
  use ApiWeb.ConnCase, async: true

  describe "authorization" do
    test "returns 401 when token is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/categories")

      assert %{"error" => "unauthorized"} = json_response(conn, 401)
    end
  end

  describe "categories CRUD" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "creates, shows, updates and deletes category", %{conn: conn} do
      create_payload = %{
        "name" => "Technology",
        "slug" => "technology",
        "description" => "Tech news"
      }

      create_conn = post(conn, "/api/v1/categories", create_payload)
      assert %{"data" => created} = json_response(create_conn, 201)
      assert created["name"] == "Technology"
      assert created["slug"] == "technology"

      id = created["id"]

      show_conn = get(conn, "/api/v1/categories/#{id}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["id"] == id

      update_conn =
        put(conn, "/api/v1/categories/#{id}", %{
          "name" => "Tech Updated",
          "slug" => "technology-updated"
        })

      assert %{"data" => updated} = json_response(update_conn, 200)
      assert updated["name"] == "Tech Updated"
      assert updated["slug"] == "technology-updated"

      delete_conn = delete(conn, "/api/v1/categories/#{id}")
      assert response(delete_conn, 204)

      not_found_conn = get(conn, "/api/v1/categories/#{id}")
      assert %{"error" => "not_found"} = json_response(not_found_conn, 404)
    end
  end
end
