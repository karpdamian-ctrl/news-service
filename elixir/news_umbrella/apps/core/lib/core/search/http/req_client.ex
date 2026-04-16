defmodule Core.Search.HTTP.ReqClient do
  @moduledoc false

  @behaviour Core.Search.HttpClient

  @impl true
  def request(method, url, headers, body, opts) do
    request_opts =
      [
        method: method,
        url: url,
        headers: headers,
        finch: Core.Finch,
        receive_timeout: Keyword.get(opts, :timeout, 15_000)
      ]
      |> maybe_put_body(body)

    case Req.request(request_opts) do
      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put_body(opts, nil), do: opts
  defp maybe_put_body(opts, ""), do: Keyword.put(opts, :body, "")
  defp maybe_put_body(opts, body) when is_binary(body), do: Keyword.put(opts, :body, body)
  defp maybe_put_body(opts, body) when is_map(body), do: Keyword.put(opts, :json, body)
end
