defmodule ApiWeb.CategoryController do
  use ApiWeb, :controller

  alias ApiWeb.ControllerHelpers
  alias ApiWeb.NewsJSON
  alias Core.News

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
