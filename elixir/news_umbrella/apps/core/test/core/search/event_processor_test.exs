defmodule Core.Search.EventProcessorTest do
  use ExUnit.Case, async: true

  alias Core.Search.EventProcessor

  defmodule FakeHttpClient do
    @behaviour Core.Search.HttpClient

    @impl true
    def request(method, url, headers, body, _opts) do
      send(self(), {:http_request, method, url, headers, body})

      case method do
        :put -> {:ok, %{status: 200, body: %{}}}
        :delete -> {:ok, %{status: 200, body: %{}}}
        _ -> {:ok, %{status: 200, body: %{}}}
      end
    end
  end

  test "upsert event indexes one document" do
    mapper = fn :articles, %{id: id, title: title} -> %{id: id, title: title} end

    assert :ok =
             EventProcessor.process({:upsert, :articles, %{id: 15, title: "A"}},
               http_client: FakeHttpClient,
               base_url: "http://elastic.test",
               mapper: mapper
             )

    assert_received {:http_request, :put, "http://elastic.test/articles_v1/_doc/15", _, body}
    assert body.id == 15
    assert body.title == "A"
  end

  test "delete event removes one document" do
    assert :ok =
             EventProcessor.process({:delete, :tags, 77},
               http_client: FakeHttpClient,
               base_url: "http://elastic.test"
             )

    assert_received {:http_request, :delete, "http://elastic.test/tags_v1/_doc/77", _, _}
  end

  test "reindex articles event upserts existing and deletes missing" do
    mapper = fn :articles, %{id: id} -> %{id: id, title: "mapped-#{id}"} end

    get_article = fn
      10 -> %{id: 10}
      _ -> nil
    end

    assert :ok =
             EventProcessor.process({:reindex_articles, [10, 11]},
               http_client: FakeHttpClient,
               base_url: "http://elastic.test",
               mapper: mapper,
               get_article: get_article
             )

    assert_received {:http_request, :put, "http://elastic.test/articles_v1/_doc/10", _, _}
    assert_received {:http_request, :delete, "http://elastic.test/articles_v1/_doc/11", _, _}
  end
end
