defmodule ApiWeb.Plugs.ApiAuditLogTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Plug.Conn
  require Logger

  alias ApiWeb.Plugs.ApiAuditLog

  test "emits API_AUDIT log with sanitized params and request metadata" do
    conn =
      :post
      |> build_conn("/api/v1/categories")
      |> Map.put(:params, %{
        "title" => String.duplicate("a", 520),
        "status" => "draft",
        "password" => "secret-password",
        "authorization" => "Bearer hidden",
        "ignored_field" => "do-not-log"
      })
      |> Map.put(:path_params, %{})
      |> put_private(:phoenix_controller, ApiWeb.CategoryController)
      |> put_private(:phoenix_action, :create)

    previous_level = Logger.level()
    Logger.configure(level: :info)

    log =
      try do
        capture_log(fn ->
          conn
          |> ApiAuditLog.call([])
          |> send_resp(201, ~s({"ok":true}))
        end)
      after
        Logger.configure(level: previous_level)
      end

    json_payload =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "API_AUDIT "))
      |> String.split("API_AUDIT ", parts: 2)
      |> List.last()

    payload = Jason.decode!(json_payload)

    assert payload["event"] == "api.request"
    assert payload["operation"] == "create"
    assert payload["resource"] == "categories"
    assert payload["method"] == "POST"
    assert payload["path"] == "/api/v1/categories"
    assert payload["status"] == 201
    assert payload["controller"] == "ApiWeb.CategoryController"
    assert payload["action"] == "create"

    assert payload["params"]["status"] == "draft"
    assert String.ends_with?(payload["params"]["title"], "...[truncated]")
    refute Map.has_key?(payload["params"], "password")
    refute Map.has_key?(payload["params"], "authorization")
    refute Map.has_key?(payload["params"], "ignored_field")
    assert is_integer(payload["duration_ms"])
  end
end
