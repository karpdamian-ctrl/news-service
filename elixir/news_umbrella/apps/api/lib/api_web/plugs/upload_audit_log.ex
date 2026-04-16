defmodule ApiWeb.Plugs.UploadAuditLog do
  @moduledoc false

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if auditable_upload_request?(conn) do
      started_at = System.monotonic_time()

      register_before_send(conn, fn conn ->
        duration_ms =
          System.monotonic_time()
          |> Kernel.-(started_at)
          |> System.convert_time_unit(:native, :millisecond)

        payload = %{
          event: "asset.request",
          operation: "show",
          resource: "uploads",
          method: conn.method,
          path: conn.request_path,
          status: conn.status,
          duration_ms: duration_ms,
          request_id: request_id(conn),
          content_type: List.first(get_resp_header(conn, "content-type")),
          cache_control: List.first(get_resp_header(conn, "cache-control"))
        }

        Logger.info("MEDIA_AUDIT " <> Jason.encode!(payload))
        conn
      end)
    else
      conn
    end
  end

  defp auditable_upload_request?(conn) do
    conn.method in ["GET", "HEAD"] and String.starts_with?(conn.request_path, "/uploads/")
  end

  defp request_id(conn) do
    List.first(get_resp_header(conn, "x-request-id")) ||
      List.first(get_req_header(conn, "x-request-id"))
  end
end
