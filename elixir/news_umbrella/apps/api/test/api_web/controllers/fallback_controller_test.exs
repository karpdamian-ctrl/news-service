defmodule ApiWeb.FallbackControllerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Plug.Conn

  alias ApiWeb.FallbackController

  test "emits API_AUDIT_WARN warning log for validation errors on mutable endpoints" do
    conn =
      :post
      |> build_conn("/api/v1/articles")
      |> put_req_header("x-request-id", "req-validation-1")
      |> Map.put(:params, %{
        "title" => "",
        "status" => "draft",
        "category_ids" => [],
        "tag_ids" => []
      })
      |> Map.put(:path_params, %{})
      |> put_private(:phoenix_controller, ApiWeb.ArticleController)
      |> put_private(:phoenix_action, :create)

    changeset =
      Ecto.Changeset.change(
        {%{}, %{title: :string, category_ids: {:array, :integer}, tag_ids: {:array, :integer}}}
      )
      |> Ecto.Changeset.add_error(:title, "can't be blank")
      |> Ecto.Changeset.add_error(:category_ids, "can't be blank")
      |> Ecto.Changeset.add_error(:tag_ids, "can't be blank")

    log =
      capture_log(fn ->
        response_conn = FallbackController.call(conn, {:error, changeset})
        assert response_conn.status == 422
        assert %{"errors" => errors} = Jason.decode!(response_conn.resp_body)
        assert Map.has_key?(errors, "title")
      end)

    json_payload =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "API_AUDIT_WARN "))
      |> String.split("API_AUDIT_WARN ", parts: 2)
      |> List.last()

    payload = Jason.decode!(json_payload)

    assert payload["event"] == "api.validation_error"
    assert payload["operation"] == "create"
    assert payload["resource"] == "articles"
    assert payload["method"] == "POST"
    assert payload["path"] == "/api/v1/articles"
    assert payload["status"] == 422
    assert payload["request_id"] == "req-validation-1"
    assert payload["controller"] == "ApiWeb.ArticleController"
    assert payload["action"] == "create"
    assert payload["params"]["status"] == "draft"
    assert payload["params"]["category_ids"] == []
    assert payload["params"]["tag_ids"] == []
    assert Map.has_key?(payload["errors"], "title")
  end

  test "does not emit API_AUDIT_WARN for validation errors on GET requests" do
    conn =
      :get
      |> build_conn("/api/v1/articles")
      |> Map.put(:params, %{"q" => "test"})
      |> Map.put(:path_params, %{})
      |> put_private(:phoenix_controller, ApiWeb.ArticleController)
      |> put_private(:phoenix_action, :index)

    changeset =
      Ecto.Changeset.change({%{}, %{title: :string}})
      |> Ecto.Changeset.add_error(:title, "can't be blank")

    log =
      capture_log(fn ->
        response_conn = FallbackController.call(conn, {:error, changeset})
        assert response_conn.status == 422
      end)

    refute log =~ "API_AUDIT_WARN"
  end
end
