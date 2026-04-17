defmodule ApiWeb.ArticleController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News
  alias Core.Search.Searcher

  action_fallback ApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{entries: entries, meta: meta}} <- News.list_articles(params) do
      conn
      |> put_status(:ok)
      |> json(ControllerHelpers.collection_response(entries, &NewsJSON.article/1, meta))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, article} <- News.get_article(id) |> ControllerHelpers.fetch_or_not_found() do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.article(article)})
    end
  end

  def search(conn, params) do
    with {:ok, %{documents: documents, meta: meta}} <-
           Searcher.search_documents(:articles, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: documents, meta: meta})
    end
  end

  def create(conn, params) do
    with {:ok, article} <- News.create_article(params) do
      conn |> put_status(:created) |> json(%{data: NewsJSON.article(article)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, article} <- News.get_article(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, article} <- News.update_article(article, Map.delete(params, "id")) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.article(article)})
    end
  end

  def increment_view(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, article} <- News.get_article(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, article} <- News.increment_article_view_count(article) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.article(article)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, article} <- News.get_article(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, _} <- News.delete_article(article) do
      send_resp(conn, :no_content, "")
    end
  end
end
