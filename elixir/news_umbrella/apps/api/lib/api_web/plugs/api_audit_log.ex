defmodule ApiWeb.Plugs.ApiAuditLog do
  @moduledoc false

  import Plug.Conn
  require Logger

  @sensitive_keys ~w(password token access_token api_token authorization)
  @allowed_param_keys ~w(
    page
    per_page
    sort
    order
    q
    filter
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
  @max_string_size 500

  def init(opts), do: opts

  def call(conn, _opts) do
    started_at = System.monotonic_time()

    register_before_send(conn, fn conn ->
      duration_ms =
        System.monotonic_time()
        |> Kernel.-(started_at)
        |> System.convert_time_unit(:native, :millisecond)

      payload = %{
        event: "api.request",
        operation: operation(conn),
        resource: resource(conn),
        method: conn.method,
        path: conn.request_path,
        query_string: conn.query_string,
        status: conn.status,
        duration_ms: duration_ms,
        request_id: request_id(conn),
        controller: controller_name(conn),
        action: action_name(conn),
        params: audit_params(conn.params || %{})
      }

      Logger.info("API_AUDIT " <> Jason.encode!(payload))
      conn
    end)
  end

  defp operation(conn) do
    id_present? = Map.has_key?(conn.path_params || %{}, "id")

    case conn.method do
      "GET" -> if(id_present?, do: "show", else: "index")
      "POST" -> "create"
      "PUT" -> "update"
      "PATCH" -> "update"
      "DELETE" -> "delete"
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
    List.first(get_resp_header(conn, "x-request-id")) ||
      List.first(get_req_header(conn, "x-request-id"))
  end

  defp controller_name(conn) do
    case conn.private[:phoenix_controller] do
      nil -> nil
      module -> inspect(module)
    end
  end

  defp action_name(conn) do
    case conn.private[:phoenix_action] do
      nil -> nil
      action -> Atom.to_string(action)
    end
  end

  defp sanitize(%{} = data) do
    data
    |> Enum.map(fn {key, value} ->
      string_key = to_string(key)

      sanitized_value =
        if String.downcase(string_key) in @sensitive_keys do
          "[REDACTED]"
        else
          sanitize(value)
        end

      {string_key, sanitized_value}
    end)
    |> Enum.into(%{})
  end

  defp sanitize(list) when is_list(list), do: Enum.map(list, &sanitize/1)

  defp sanitize(value) when is_binary(value) do
    if String.length(value) > @max_string_size do
      String.slice(value, 0, @max_string_size) <> "...[truncated]"
    else
      value
    end
  end

  defp sanitize(value), do: value

  defp audit_params(params) when is_map(params) do
    params
    |> Map.take(@allowed_param_keys)
    |> sanitize()
  end

  defp audit_params(_), do: %{}
end
