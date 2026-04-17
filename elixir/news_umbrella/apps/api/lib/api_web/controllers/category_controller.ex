defmodule ApiWeb.CategoryController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News
  alias Core.Search.Searcher

  action_fallback ApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{entries: entries, meta: meta}} <- News.list_categories(params) do
      conn
      |> put_status(:ok)
      |> json(ControllerHelpers.collection_response(entries, &NewsJSON.category/1, meta))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, category} <- News.get_category(id) |> ControllerHelpers.fetch_or_not_found() do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.category(category)})
    end
  end

  def search(conn, params) do
    with {:ok, %{documents: documents, meta: meta}} <-
           Searcher.search_documents(:categories, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: documents, meta: meta})
    end
  end

  def popular(conn, params) do
    limit = parse_limit(Map.get(params, "limit", "5"))

    search_params = %{
      "limit" => Integer.to_string(limit),
      "filter" => %{"status" => "published"}
    }

    with {:ok, %{terms: terms, meta: meta}} <-
           Searcher.top_terms(:articles, "category_refs", search_params) do
      parsed_terms = Enum.map(terms, &parse_category_term/1)

      data =
        Enum.map(parsed_terms, fn %{id: id, slug: slug, name: name, count: count} ->
          %{id: id, slug: slug, name: name, count: count}
        end)

      response_meta =
        meta
        |> Map.put(:total_count, length(parsed_terms))
        |> Map.put(:limit, limit)

      conn
      |> put_status(:ok)
      |> json(%{data: data, meta: response_meta})
    end
  end

  defp parse_limit(value) do
    case Integer.parse(to_string(value)) do
      {limit, ""} when limit > 0 -> min(limit, 100)
      _ -> 5
    end
  end

  defp parse_category_term(%{term: term, count: count}) do
    case String.split(to_string(term), "|", parts: 3) do
      [id, slug, name] ->
        %{id: parse_int(id), slug: slug, name: name, count: count}

      [name] ->
        %{id: nil, slug: nil, name: name, count: count}

      _ ->
        %{id: nil, slug: nil, name: to_string(term), count: count}
    end
  end

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def create(conn, params) do
    with {:ok, category} <- News.create_category(params) do
      conn |> put_status(:created) |> json(%{data: NewsJSON.category(category)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, category} <- News.get_category(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, category} <- News.update_category(category, Map.delete(params, "id")) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.category(category)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, category} <- News.get_category(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, _} <- News.delete_category(category) do
      send_resp(conn, :no_content, "")
    end
  end
end
