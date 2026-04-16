defmodule ApiWeb.MediaControllerTest do
  use ApiWeb.ConnCase, async: true

  describe "media CRUD" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "creates, shows, updates and deletes media", %{conn: conn} do
      create_conn =
        post(conn, "/api/v1/media", %{
          "type" => "image",
          "path" => "/uploads/news/test-photo.jpg",
          "mime_type" => "image/jpeg",
          "size_bytes" => 250_000,
          "alt_text" => "Test photo",
          "caption" => "Caption",
          "uploaded_by" => "Editor"
        })

      assert %{"data" => created} = json_response(create_conn, 201)
      id = created["id"]

      show_conn = get(conn, "/api/v1/media/#{id}")
      assert %{"data" => shown} = json_response(show_conn, 200)
      assert shown["path"] == "/uploads/news/test-photo.jpg"

      update_conn =
        put(conn, "/api/v1/media/#{id}", %{
          "type" => "image",
          "path" => "/uploads/news/test-photo-updated.jpg",
          "mime_type" => "image/jpeg"
        })

      assert %{"data" => updated} = json_response(update_conn, 200)
      assert updated["path"] == "/uploads/news/test-photo-updated.jpg"

      delete_conn = delete(conn, "/api/v1/media/#{id}")
      assert response(delete_conn, 204)
    end

    test "returns 422 for invalid media path", %{conn: conn} do
      conn =
        post(conn, "/api/v1/media", %{
          "type" => "image",
          "path" => "/tmp/outside.jpg"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "path")
    end
  end
end
