defmodule Core.Search.IndexerTest do
  use ExUnit.Case, async: true

  alias Core.Search.Indexer

  defmodule FakeHttpClient do
    @behaviour Core.Search.HttpClient

    @impl true
    def request(method, url, headers, body, _opts) do
      send(self(), {:http_call, method, url, headers, body})

      case {method, url} do
        {:delete, "http://elastic.test/articles_v1"} ->
          {:ok, %{status: 404, body: %{}}}

        {:put, "http://elastic.test/articles_v1"} ->
          {:ok, %{status: 200, body: %{}}}

        {:post, "http://elastic.test/_bulk"} ->
          {:ok, %{status: 200, body: %{"errors" => false}}}

        {:post, "http://elastic.test/articles_v1/_refresh"} ->
          {:ok, %{status: 200, body: %{}}}

        _ ->
          {:error, {:unexpected_call, method, url}}
      end
    end
  end

  defmodule FakeBulkErrorHttpClient do
    @behaviour Core.Search.HttpClient

    @impl true
    def request(method, url, _headers, _body, _opts) do
      case {method, url} do
        {:delete, "http://elastic.test/articles_v1"} -> {:ok, %{status: 404, body: %{}}}
        {:put, "http://elastic.test/articles_v1"} -> {:ok, %{status: 200, body: %{}}}
        {:post, "http://elastic.test/_bulk"} -> {:ok, %{status: 200, body: %{"errors" => true}}}
        _ -> {:ok, %{status: 200, body: %{}}}
      end
    end
  end

  test "reindex_resource resets index and loads documents" do
    fetcher = fn {_module, _function}, _opts ->
      {:ok, [%{id: 10, title: "First"}, %{id: 11, title: "Second"}]}
    end

    mapper = fn :articles, entry ->
      %{id: entry.id, title: entry.title}
    end

    assert {:ok, %{indexed_count: 2, index: "articles_v1", resource: :articles}} =
             Indexer.reindex_resource(:articles,
               http_client: FakeHttpClient,
               base_url: "http://elastic.test",
               fetcher: fetcher,
               mapper: mapper,
               chunk_size: 1
             )

    assert_received {:http_call, :delete, "http://elastic.test/articles_v1", _, _}
    assert_received {:http_call, :put, "http://elastic.test/articles_v1", _, _}
    assert_received {:http_call, :post, "http://elastic.test/_bulk", _, bulk_body}
    assert_received {:http_call, :post, "http://elastic.test/articles_v1/_refresh", _, _}

    assert bulk_body =~ "\"_id\":10"
    assert bulk_body =~ "\"title\":\"First\""
  end

  test "returns error when elastic bulk response contains errors" do
    fetcher = fn {_module, _function}, _opts -> {:ok, [%{id: 99, title: "Invalid"}]} end
    mapper = fn :articles, entry -> %{id: entry.id, title: entry.title} end

    assert {:error, {:bulk_failed, _body}} =
             Indexer.reindex_resource(:articles,
               http_client: FakeBulkErrorHttpClient,
               base_url: "http://elastic.test",
               fetcher: fetcher,
               mapper: mapper
             )
  end
end
