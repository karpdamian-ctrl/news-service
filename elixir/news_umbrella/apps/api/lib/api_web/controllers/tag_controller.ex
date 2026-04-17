defmodule ApiWeb.TagController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News
  alias Core.Search.Searcher

  action_fallback ApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{entries: entries, meta: meta}} <- News.list_tags(params) do
      conn
      |> put_status(:ok)
      |> json(ControllerHelpers.collection_response(entries, &NewsJSON.tag/1, meta))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, tag} <- News.get_tag(id) |> ControllerHelpers.fetch_or_not_found() do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.tag(tag)})
    end
  end

  def search(conn, params) do
    with {:ok, %{documents: documents, meta: meta}} <- Searcher.search_documents(:tags, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: documents, meta: meta})
    end
  end

  def create(conn, params) do
    with {:ok, tag} <- News.create_tag(params) do
      conn |> put_status(:created) |> json(%{data: NewsJSON.tag(tag)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, tag} <- News.get_tag(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, tag} <- News.update_tag(tag, Map.delete(params, "id")) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.tag(tag)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, tag} <- News.get_tag(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, _} <- News.delete_tag(tag) do
      send_resp(conn, :no_content, "")
    end
  end
end
