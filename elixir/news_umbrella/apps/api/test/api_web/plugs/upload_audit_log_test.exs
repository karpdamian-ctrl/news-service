defmodule ApiWeb.Plugs.UploadAuditLogTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Plug.Conn
  require Logger

  alias ApiWeb.Plugs.UploadAuditLog

  test "emits MEDIA_AUDIT log for GET /uploads requests" do
    conn =
      :get
      |> build_conn("/uploads/news/example.jpg")
      |> put_req_header("x-request-id", "req-upload-1")
      |> put_resp_content_type("image/jpeg")
      |> put_resp_header("cache-control", "public, max-age=3600")

    previous_level = Logger.level()
    Logger.configure(level: :info)

    log =
      try do
        capture_log(fn ->
          conn
          |> UploadAuditLog.call([])
          |> send_resp(200, "")
        end)
      after
        Logger.configure(level: previous_level)
      end

    json_payload =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "MEDIA_AUDIT "))
      |> String.split("MEDIA_AUDIT ", parts: 2)
      |> List.last()

    payload = Jason.decode!(json_payload)

    assert payload["event"] == "asset.request"
    assert payload["operation"] == "show"
    assert payload["resource"] == "uploads"
    assert payload["method"] == "GET"
    assert payload["path"] == "/uploads/news/example.jpg"
    assert payload["status"] == 200
    assert payload["request_id"] == "req-upload-1"
    assert payload["content_type"] == "image/jpeg; charset=utf-8"
    assert payload["cache_control"] == "public, max-age=3600"
    assert is_integer(payload["duration_ms"])
  end

  test "does not emit MEDIA_AUDIT log for non-upload path" do
    conn = build_conn(:get, "/api/v1/categories")

    previous_level = Logger.level()
    Logger.configure(level: :info)

    log =
      try do
        capture_log(fn ->
          conn
          |> UploadAuditLog.call([])
          |> send_resp(200, "ok")
        end)
      after
        Logger.configure(level: previous_level)
      end

    refute log =~ "MEDIA_AUDIT"
  end
end
