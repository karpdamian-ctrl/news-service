defmodule ApiWeb.Plugs.ApiTokenAuth do
  @moduledoc false

  import Plug.Conn
  alias Plug.Crypto

  def init(opts), do: opts

  def call(conn, _opts) do
    case Application.fetch_env(:api, :access_token) do
      {:ok, expected_token} ->
        if valid_token?(conn, expected_token) do
          conn
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(:unauthorized, ~s({"error":"unauthorized"}))
          |> halt()
        end

      :error ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:internal_server_error, ~s({"error":"api_token_not_configured"}))
        |> halt()
    end
  end

  defp valid_token?(conn, expected_token) do
    bearer =
      conn
      |> get_req_header("authorization")
      |> List.first()
      |> parse_bearer()

    header_token = conn |> get_req_header("x-api-token") |> List.first()

    token_matches?(bearer, expected_token) or token_matches?(header_token, expected_token)
  end

  defp token_matches?(provided, expected)
       when is_binary(provided) and is_binary(expected) and
              byte_size(provided) == byte_size(expected) do
    Crypto.secure_compare(provided, expected)
  end

  defp token_matches?(_, _), do: false

  defp parse_bearer("Bearer " <> token), do: token
  defp parse_bearer(_), do: nil
end
