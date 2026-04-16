defmodule Core.Search.HttpClient do
  @moduledoc false

  @callback request(
              method :: :get | :post | :put | :delete,
              url :: String.t(),
              headers :: [{String.t(), String.t()}],
              body :: nil | binary() | map(),
              opts :: keyword()
            ) ::
              {:ok, %{status: pos_integer(), body: any()}} | {:error, term()}

  @default_timeout 15_000

  def reset_index(index, definition, opts \\ []) do
    with :ok <- delete_index(index, opts),
         :ok <- create_index(index, definition, opts) do
      :ok
    end
  end

  def bulk_index(index, documents, opts \\ []) when is_list(documents) do
    payload = bulk_payload(index, documents)

    with {:ok, %{status: status, body: body}} when status in [200, 201] <-
           request(:post, "/_bulk", [{"content-type", "application/x-ndjson"}], payload, opts),
         :ok <- ensure_bulk_success(body) do
      :ok
    else
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def upsert_document(index, document, opts \\ []) when is_map(document) do
    id = Map.fetch!(document, :id)

    case request(
           :put,
           "/#{index}/_doc/#{id}",
           [{"content-type", "application/json"}],
           document,
           opts
         ) do
      {:ok, %{status: status}} when status in [200, 201] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_document(index, id, opts \\ []) do
    case request(:delete, "/#{index}/_doc/#{id}", [], nil, opts) do
      {:ok, %{status: status}} when status in [200, 202, 404] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh_index(index, opts \\ []) do
    case request(:post, "/#{index}/_refresh", [], "", opts) do
      {:ok, %{status: status}} when status in [200, 201] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_index(index, opts) do
    case request(:delete, "/#{index}", [], nil, opts) do
      {:ok, %{status: status}} when status in [200, 202, 404] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_index(index, definition, opts) do
    body = %{
      settings: definition.settings,
      mappings: definition.mappings
    }

    case request(:put, "/#{index}", [{"content-type", "application/json"}], body, opts) do
      {:ok, %{status: status}} when status in [200, 201] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(method, path, headers, body, opts) do
    client = Keyword.get(opts, :http_client, Core.Search.HTTP.ReqClient)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    url = elasticsearch_url(opts) <> path

    client.request(method, url, headers, body, timeout: timeout)
  end

  defp elasticsearch_url(opts) do
    case Keyword.get(opts, :base_url) do
      nil ->
        Application.get_env(:core, :integrations, [])
        |> Keyword.get(:elasticsearch_url, "http://localhost:9200")
        |> String.trim_trailing("/")

      value ->
        value |> to_string() |> String.trim_trailing("/")
    end
  end

  defp ensure_bulk_success(%{"errors" => false}), do: :ok
  defp ensure_bulk_success(%{errors: false}), do: :ok
  defp ensure_bulk_success(body), do: {:error, {:bulk_failed, body}}

  defp bulk_payload(index, documents) do
    Enum.map_join(documents, "", fn document ->
      id = Map.fetch!(document, :id)
      action = Jason.encode!(%{index: %{_index: index, _id: id}})
      source = Jason.encode!(document)
      action <> "\n" <> source <> "\n"
    end)
  end
end
