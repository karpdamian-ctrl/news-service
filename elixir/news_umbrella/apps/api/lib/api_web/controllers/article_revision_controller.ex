defmodule ApiWeb.ArticleRevisionController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News

  action_fallback ApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{entries: entries, meta: meta}} <- News.list_article_revisions(params) do
      conn
      |> put_status(:ok)
      |> json(ControllerHelpers.collection_response(entries, &NewsJSON.article_revision/1, meta))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, revision} <-
           News.get_article_revision(id) |> ControllerHelpers.fetch_or_not_found() do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.article_revision(revision)})
    end
  end

  def create(conn, params) do
    with {:ok, revision} <- News.create_article_revision(params) do
      conn |> put_status(:created) |> json(%{data: NewsJSON.article_revision(revision)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, revision} <-
           News.get_article_revision(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, revision} <- News.update_article_revision(revision, Map.delete(params, "id")) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.article_revision(revision)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, revision} <-
           News.get_article_revision(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, _} <- News.delete_article_revision(revision) do
      send_resp(conn, :no_content, "")
    end
  end
end
