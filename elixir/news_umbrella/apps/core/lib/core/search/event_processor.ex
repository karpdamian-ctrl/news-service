defmodule Core.Search.EventProcessor do
  @moduledoc false

  alias Core.News
  alias Core.Search.{DocumentMapper, Documents, HttpClient}

  def process(event, opts \\ [])

  def process({:upsert, resource, struct}, opts) when is_atom(resource) do
    with definition <- Documents.definition!(resource),
         {:ok, document} <- map_document(resource, struct, opts),
         :ok <- HttpClient.upsert_document(definition.index, document, opts) do
      :ok
    end
  rescue
    error -> {:error, {:event_failed, Exception.message(error)}}
  end

  def process({:delete, resource, id}, opts) when is_atom(resource) do
    with definition <- Documents.definition!(resource),
         :ok <- HttpClient.delete_document(definition.index, id, opts) do
      :ok
    end
  rescue
    error -> {:error, {:event_failed, Exception.message(error)}}
  end

  def process({:reindex_articles, ids}, opts) when is_list(ids) do
    get_article = Keyword.get(opts, :get_article, &News.get_article/1)

    ids
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn id, :ok ->
      case get_article.(id) do
        nil ->
          case process({:delete, :articles, id}, opts) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        article ->
          case process({:upsert, :articles, article}, opts) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  def process({:reindex_article_revisions, ids}, opts) when is_list(ids) do
    get_article_revision = Keyword.get(opts, :get_article_revision, &News.get_article_revision/1)

    ids
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn id, :ok ->
      case get_article_revision.(id) do
        nil ->
          case process({:delete, :article_revisions, id}, opts) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        revision ->
          case process({:upsert, :article_revisions, revision}, opts) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  def process(event, _opts), do: {:error, {:unsupported_event, event}}

  defp map_document(resource, struct, opts) do
    mapper = Keyword.get(opts, :mapper, &DocumentMapper.to_document/2)

    {:ok, mapper.(resource, struct)}
  rescue
    error -> {:error, {:mapping_failed, Exception.message(error)}}
  end
end
