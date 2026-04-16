defmodule ApiWeb.FallbackController do
  use ApiWeb, :controller
  require Logger

  @mutable_methods ~w(POST PUT PATCH DELETE)
  @allowed_param_keys ~w(
    id
    status
    slug
    title
    author
    type
    article_id
    changed_by
    category_ids
    tag_ids
  )

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = translate_errors(changeset)
    maybe_log_validation_warning(conn, errors)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: errors})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request"})
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp maybe_log_validation_warning(conn, errors) do
    if conn.method in @mutable_methods do
      payload = %{
        event: "api.validation_error",
        operation: operation(conn),
        resource: resource(conn),
        method: conn.method,
        path: conn.request_path,
        status: 422,
        request_id: request_id(conn),
        controller: audit_controller_name(conn),
        action: audit_action_name(conn),
        params: audit_params(conn.params || %{}),
        errors: errors
      }

      Logger.warning("API_AUDIT_WARN " <> Jason.encode!(payload))
    end
  end

  defp operation(conn) do
    id_present? = Map.has_key?(conn.path_params || %{}, "id")

    case conn.method do
      "POST" -> "create"
      "PUT" -> "update"
      "PATCH" -> "update"
      "DELETE" -> "delete"
      "GET" -> if(id_present?, do: "show", else: "index")
      _ -> "unknown"
    end
  end

  defp resource(conn) do
    segments = String.split(conn.request_path, "/", trim: true)
    id_present? = Map.has_key?(conn.path_params || %{}, "id")

    case {id_present?, segments} do
      {true, [_api, _version, resource, _id]} -> resource
      {false, [_api, _version, resource]} -> resource
      _ -> "unknown"
    end
  end

  defp request_id(conn) do
    List.first(Plug.Conn.get_resp_header(conn, "x-request-id")) ||
      List.first(Plug.Conn.get_req_header(conn, "x-request-id"))
  end

  defp audit_controller_name(conn) do
    case conn.private[:phoenix_controller] do
      nil -> nil
      module -> inspect(module)
    end
  end

  defp audit_action_name(conn) do
    case conn.private[:phoenix_action] do
      nil -> nil
      action -> Atom.to_string(action)
    end
  end

  defp audit_params(params) when is_map(params) do
    Map.take(params, @allowed_param_keys)
  end

  defp audit_params(_), do: %{}
end
