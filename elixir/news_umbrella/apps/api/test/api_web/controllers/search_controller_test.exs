defmodule ApiWeb.SearchControllerTest do
  use ApiWeb.ConnCase, async: false

  defmodule FakeSearchHttpClient do
    @behaviour Core.Search.HttpClient

    @impl true
    def request(:post, url, _headers, body, _opts) do
      send(self(), {:elastic_request, url, body})

      if Map.has_key?(body, :aggs) || Map.has_key?(body, "aggs") do
        return_aggregations()
      else
        source =
          cond do
            String.contains?(url, "/categories_v1/_search") ->
              %{"id" => 1, "name" => "Technology", "slug" => "technology"}

            String.contains?(url, "/tags_v1/_search") ->
              %{"id" => 2, "name" => "AI", "slug" => "ai"}

            String.contains?(url, "/media_v1/_search") ->
              %{"id" => 3, "path" => "/uploads/news/example.jpg", "type" => "image"}

            String.contains?(url, "/articles_v1/_search") ->
              %{"id" => 4, "title" => "AI Weekly", "slug" => "ai-weekly"}

            String.contains?(url, "/article_revisions_v1/_search") ->
              %{"id" => 5, "article_id" => 4, "title" => "AI Weekly v1"}

            true ->
              %{"id" => 999}
          end

        {:ok,
         %{
           status: 200,
           body: %{
             "took" => 7,
             "hits" => %{
               "total" => %{"value" => 1},
               "hits" => [
                 %{"_id" => to_string(source["id"]), "_score" => 1.0, "_source" => source}
               ]
             }
           }
         }}
      end
    end

    defp return_aggregations do
      {:ok,
       %{
         status: 200,
         body: %{
           "took" => 4,
           "aggregations" => %{
             "top_terms" => %{
               "buckets" => [
                 %{"key" => "1|technology|Technology", "doc_count" => 21},
                 %{"key" => "2|economy|Economy", "doc_count" => 15}
               ]
             }
           }
         }
       }}
    end
  end

  setup %{conn: conn} do
    previous = Application.get_env(:core, :search_http_client)
    Application.put_env(:core, :search_http_client, FakeSearchHttpClient)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:core, :search_http_client)
      else
        Application.put_env(:core, :search_http_client, previous)
      end
    end)

    {:ok, conn: authenticated_conn(conn)}
  end

  test "search endpoints return documents from elastic", %{conn: conn} do
    endpoints = [
      {"/api/v1/categories/search", "name", "Technology"},
      {"/api/v1/tags/search", "name", "AI"},
      {"/api/v1/media/search", "path", "/uploads/news/example.jpg"},
      {"/api/v1/articles/search", "title", "AI Weekly"},
      {"/api/v1/article-revisions/search", "title", "AI Weekly v1"}
    ]

    Enum.each(endpoints, fn {path, expected_field, expected_value} ->
      response_conn =
        get(conn, path, %{
          "q" => "ai",
          "page" => "1",
          "per_page" => "5",
          "sort" => "id",
          "order" => "desc"
        })

      assert %{"data" => [doc], "meta" => meta} = json_response(response_conn, 200)
      assert doc[expected_field] == expected_value
      assert meta["source"] == "elasticsearch"
      assert meta["total_count"] == 1
      assert meta["page"] == 1
      assert meta["per_page"] == 5
    end)
  end

  test "translates filter params into elastic request body", %{conn: conn} do
    _conn =
      get(conn, "/api/v1/articles/search", %{
        "q" => "cloud",
        "filter" => %{"status" => "published", "is_breaking" => "true"},
        "sort" => "published_at",
        "order" => "asc",
        "page" => "2",
        "per_page" => "10"
      })

    assert_received {:elastic_request, url, body}
    assert String.contains?(url, "/articles_v1/_search")
    assert body.from == 10
    assert body.size == 10
    assert body.sort == [%{"published_at" => %{order: "asc"}}]
    assert get_in(body, [:query, :bool, :must]) |> is_list()
  end

  test "categories popular endpoint returns top category names from elastic aggregation", %{
    conn: conn
  } do
    response_conn = get(conn, "/api/v1/categories/popular", %{"limit" => "5"})

    assert %{"data" => data, "meta" => meta} = json_response(response_conn, 200)

    assert [
             %{
               "id" => 1,
               "slug" => "technology",
               "name" => "Technology",
               "count" => 21
             },
             %{
               "id" => 2,
               "slug" => "economy",
               "name" => "Economy",
               "count" => 15
             }
           ] = data

    assert meta["source"] == "elasticsearch"
    assert meta["limit"] == 5
    assert meta["total_count"] == 2

    assert_received {:elastic_request, url, body}
    assert String.contains?(url, "/articles_v1/_search")
    assert body.size == 0
    assert get_in(body, [:aggs, "top_terms", :terms, :field]) == "category_refs"
  end
end
