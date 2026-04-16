defmodule Core.Search.Indexer do
  @moduledoc false

  alias Core.Search.{DocumentMapper, Documents, HttpClient}

  @max_per_page 100
  @default_chunk_size 200

  @spec reset_resource(Documents.resource(), keyword()) :: :ok | {:error, term()}
  def reset_resource(resource, opts \\ []) when is_atom(resource) do
    definition = Documents.definition!(resource)
    HttpClient.reset_index(definition.index, definition, opts)
  end

  @spec load_resource(Documents.resource(), keyword()) ::
          {:ok, %{indexed_count: non_neg_integer(), index: String.t(), resource: atom()}}
          | {:error, term()}
  def load_resource(resource, opts \\ []) when is_atom(resource) do
    definition = Documents.definition!(resource)

    with {:ok, entries} <- fetch_all_entries(definition, opts),
         {:ok, documents} <- map_entries(resource, entries, opts),
         :ok <- index_chunks(definition.index, documents, opts),
         :ok <- HttpClient.refresh_index(definition.index, opts) do
      {:ok, %{resource: resource, index: definition.index, indexed_count: length(documents)}}
    end
  end

  @spec reindex_resource(Documents.resource(), keyword()) ::
          {:ok, %{indexed_count: non_neg_integer(), index: String.t(), resource: atom()}}
          | {:error, term()}
  def reindex_resource(resource, opts \\ []) when is_atom(resource) do
    with :ok <- reset_resource(resource, opts),
         {:ok, result} <- load_resource(resource, opts) do
      {:ok, result}
    end
  end

  defp index_chunks(_index, [], _opts), do: :ok

  defp index_chunks(index, documents, opts) do
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)

    documents
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce_while(:ok, fn chunk, :ok ->
      case HttpClient.bulk_index(index, chunk, opts) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp map_entries(resource, entries, opts) do
    mapper = Keyword.get(opts, :mapper, &DocumentMapper.to_document/2)

    try do
      {:ok, Enum.map(entries, &mapper.(resource, &1))}
    rescue
      error -> {:error, {:map_failed, Exception.message(error)}}
    end
  end

  defp fetch_all_entries(definition, opts) do
    fetcher = Keyword.get(opts, :fetcher, &default_fetcher/2)

    case fetcher.(definition.source, opts) do
      {:ok, entries} when is_list(entries) -> {:ok, entries}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_fetcher_result, other}}
    end
  end

  defp default_fetcher({module, function}, _opts) do
    fetch_page_entries(module, function, 1, [])
  end

  defp fetch_page_entries(module, function, page, acc) do
    params = %{"page" => page, "per_page" => @max_per_page, "sort" => "id", "order" => "asc"}

    case apply(module, function, [params]) do
      {:ok, %{entries: entries, meta: %{has_next_page: has_next_page}}} ->
        updated = acc ++ entries

        if has_next_page do
          fetch_page_entries(module, function, page + 1, updated)
        else
          {:ok, updated}
        end

      {:error, reason} ->
        {:error, {:fetch_failed, reason}}

      other ->
        {:error, {:invalid_source_response, other}}
    end
  end
end
