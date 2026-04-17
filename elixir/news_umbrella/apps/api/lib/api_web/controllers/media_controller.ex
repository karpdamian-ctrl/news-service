defmodule ApiWeb.MediaController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News
  alias Core.Search.Searcher

  action_fallback ApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, %{entries: entries, meta: meta}} <- News.list_media(params) do
      conn
      |> put_status(:ok)
      |> json(ControllerHelpers.collection_response(entries, &NewsJSON.media/1, meta))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, media} <- News.get_media(id) |> ControllerHelpers.fetch_or_not_found() do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.media(media)})
    end
  end

  def search(conn, params) do
    with {:ok, %{documents: documents, meta: meta}} <- Searcher.search_documents(:media, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: documents, meta: meta})
    end
  end

  def create(conn, params) do
    with {:ok, media} <- News.create_media(params) do
      conn |> put_status(:created) |> json(%{data: NewsJSON.media(media)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, media} <- News.get_media(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, media} <- News.update_media(media, Map.delete(params, "id")) do
      conn |> put_status(:ok) |> json(%{data: NewsJSON.media(media)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- ControllerHelpers.parse_int_id(id),
         {:ok, media} <- News.get_media(id) |> ControllerHelpers.fetch_or_not_found(),
         {:ok, _} <- News.delete_media(media) do
      send_resp(conn, :no_content, "")
    end
  end
end
