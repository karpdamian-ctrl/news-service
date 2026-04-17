defmodule ApiWeb.Plugs.ApiRateLimit do
  @moduledoc false

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?() do
      identifier = client_identifier(conn)
      backend = backend_module()

      case backend.allow_request(identifier) do
        {:ok, %{allowed: true}} ->
          conn

        {:ok, %{allowed: false, ttl: ttl, limit: limit}} ->
          Logger.warning(
            "API_RATE_LIMIT_EXCEEDED #{inspect(%{identifier: identifier, path: conn.request_path, method: conn.method, retry_after_seconds: ttl, limit: limit})}"
          )

          conn
          |> put_resp_content_type("application/json")
          |> put_resp_header("retry-after", Integer.to_string(ttl))
          |> send_resp(
            :too_many_requests,
            Jason.encode!(%{
              error: "rate_limited",
              message: "Przekroczono limit zapytan na minute. Sprobuj ponownie pozniej.",
              limit: limit,
              retry_after_seconds: ttl
            })
          )
          |> halt()

        {:error, reason} ->
          Logger.warning("API_RATE_LIMIT_ERROR #{inspect(reason)}")
          conn
      end
    else
      conn
    end
  end

  defp enabled? do
    Application.get_env(:api, :rate_limiter_enabled, true)
  end

  defp backend_module do
    Application.get_env(:api, :rate_limiter_backend, Core.RateLimiter)
  end

  defp client_identifier(conn) do
    forwarded_ip =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()
      |> first_csv_value()

    case forwarded_ip do
      ip when is_binary(ip) and ip != "" -> ip
      _ -> conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    end
  end

  defp first_csv_value(nil), do: nil

  defp first_csv_value(value) do
    value
    |> String.split(",", parts: 2)
    |> List.first()
    |> to_string()
    |> String.trim()
  end
end
