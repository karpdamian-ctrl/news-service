defmodule Core.Search.SearcherTest do
  use ExUnit.Case, async: true

  alias Core.Search.Searcher

  defmodule FakeClient do
    @behaviour Core.Search.HttpClient

    @impl true
    def request(method, url, _headers, body, _opts) do
      send(self(), {:elastic_request, method, url, body})

      if Map.has_key?(body, :aggs) || Map.has_key?(body, "aggs") do
        {:ok,
         %{
           status: 200,
           body: %{
             "took" => 5,
             "aggregations" => %{
               "top_terms" => %{
                 "buckets" => [
                   %{"key" => "Technology", "doc_count" => 12},
                   %{"key" => "Economy", "doc_count" => 8}
                 ]
               }
             }
           }
         }}
      else
        {:ok,
         %{
           status: 200,
           body: %{
             "took" => 3,
             "hits" => %{
               "total" => %{"value" => 1},
               "hits" => [
                 %{
                   "_id" => "123",
                   "_score" => 1.25,
                   "_source" => %{"id" => 123, "title" => "Elastic article"}
                 }
               ]
             }
           }
         }}
      end
    end
  end

  test "builds bool query from params and returns elastic documents" do
    assert {:ok, %{documents: docs, meta: meta}} =
             Searcher.search_documents(
               :articles,
               %{
                 "q" => "cloud ai",
                 "page" => "2",
                 "per_page" => "5",
                 "sort" => "published_at",
                 "order" => "asc",
                 "filter" => %{"status" => "published", "is_breaking" => "true"}
               },
               http_client: FakeClient,
               base_url: "http://elastic.test"
             )

    assert [%{"id" => 123, "title" => "Elastic article", "_score" => 1.25}] = docs
    assert meta.page == 2
    assert meta.per_page == 5
    assert meta.total_count == 1
    assert meta.total_pages == 1
    assert meta.query == "cloud ai"
    assert meta.source == "elasticsearch"

    assert_received {:elastic_request, :post, "http://elastic.test/articles_v1/_search", body}

    assert body.from == 5
    assert body.size == 5
    assert body.sort == [%{"published_at" => %{order: "asc"}}]
    assert get_in(body, [:query, :bool, :must]) |> is_list()
  end

  test "uses match_all query when q is empty" do
    assert {:ok, %{meta: meta}} =
             Searcher.search_documents(
               :tags,
               %{"q" => "", "page" => "1", "per_page" => "10"},
               http_client: FakeClient,
               base_url: "http://elastic.test"
             )

    assert meta.query == ""

    assert_received {:elastic_request, :post, "http://elastic.test/tags_v1/_search", body}
    assert body.query == %{match_all: %{}}
    assert body.sort == [%{id: %{order: "desc"}}]
  end

  test "returns top terms aggregation for a field" do
    assert {:ok, %{terms: terms, meta: meta}} =
             Searcher.top_terms(
               :articles,
               "category_names",
               %{"limit" => "5", "filter" => %{"status" => "published"}},
               http_client: FakeClient,
               base_url: "http://elastic.test"
             )

    assert [%{term: "Technology", count: 12}, %{term: "Economy", count: 8}] = terms
    assert meta.limit == 5
    assert meta.source == "elasticsearch"

    assert_received {:elastic_request, :post, "http://elastic.test/articles_v1/_search", body}
    assert body.size == 0
    assert get_in(body, [:aggs, "top_terms", :terms, :field]) == "category_names"
    assert get_in(body, [:aggs, "top_terms", :terms, :size]) == 5
  end

  test "converts indexed filter map into terms query list" do
    assert {:ok, _result} =
             Searcher.search_documents(
               :articles,
               %{
                 "filter" => %{
                   "status" => "published",
                   "tag_ids" => %{"0" => "95"}
                 },
                 "sort" => "published_at",
                 "order" => "desc",
                 "page" => "1",
                 "per_page" => "50"
               },
               http_client: FakeClient,
               base_url: "http://elastic.test"
             )

    assert_received {:elastic_request, :post, "http://elastic.test/articles_v1/_search", body}

    must = get_in(body, [:query, :bool, :must]) || []

    assert %{terms: %{"tag_ids" => [95]}} in must
    assert %{term: %{"status" => "published"}} in must
  end
end
