defmodule ApiWeb.ArticleRevisionController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News
  alias Core.Search.Searcher

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

  def search(conn, params) do
    with {:ok, %{documents: documents, meta: meta}} <-
           Searcher.search_documents(:article_revisions, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: documents, meta: meta})
    end
  end
end
