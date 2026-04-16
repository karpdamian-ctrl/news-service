defmodule Core.News.Query do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Core.Repo

  @default_page 1
  @default_per_page 20
  @max_per_page 100

  def list(queryable, params, opts \\ []) when is_list(opts) do
    sortable = Keyword.fetch!(opts, :sortable)
    filterable = Keyword.get(opts, :filterable, [])
    search_fields = Keyword.get(opts, :search_fields, [])
    default_sort = Keyword.get(opts, :default_sort, hd(sortable))
    default_order = Keyword.get(opts, :default_order, :desc)
    preload = Keyword.get(opts, :preload, [])

    with {:ok, page} <- parse_integer(param(params, "page"), @default_page, min: 1),
         {:ok, per_page} <-
           parse_integer(param(params, "per_page"), @default_per_page, min: 1, max: @max_per_page),
         {:ok, sort} <- parse_sort(param(params, "sort"), sortable, default_sort),
         {:ok, order} <- parse_order(param(params, "order"), default_order),
         {:ok, query} <-
           apply_filters(from(q in queryable), queryable, param(params, "filter"), filterable),
         {:ok, query} <- apply_search(query, param(params, "q"), search_fields) do
      total_count = Repo.aggregate(query, :count, :id)
      total_pages = total_pages(total_count, per_page)
      page = min(page, total_pages)

      entries =
        query
        |> apply_sort(sort, order)
        |> limit(^per_page)
        |> offset(^((page - 1) * per_page))
        |> Repo.all()
        |> maybe_preload(preload)

      {:ok,
       %{
         entries: entries,
         meta: %{
           page: page,
           per_page: per_page,
           total_count: total_count,
           total_pages: total_pages,
           sort: Atom.to_string(sort),
           order: Atom.to_string(order),
           has_prev_page: page > 1,
           has_next_page: page < total_pages
         }
       }}
    end
  end

  defp apply_sort(query, sort, order), do: from(q in query, order_by: [{^order, field(q, ^sort)}])

  defp apply_filters(query, _queryable, nil, _filterable), do: {:ok, query}

  defp apply_filters(query, _queryable, filters, _filterable)
       when is_map(filters) and map_size(filters) == 0,
       do: {:ok, query}

  defp apply_filters(query, queryable, filters, filterable) when is_map(filters) do
    Enum.reduce_while(filters, {:ok, query}, fn {key, value}, {:ok, acc} ->
      with {:ok, field} <- to_filter_field(key, filterable),
           {:ok, next_query} <- apply_filter(acc, queryable, field, value) do
        {:cont, {:ok, next_query}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_filters(_query, _queryable, _filters, _filterable), do: {:error, :bad_request}

  defp apply_search(query, nil, _search_fields), do: {:ok, query}
  defp apply_search(query, "", _search_fields), do: {:ok, query}
  defp apply_search(query, _q, []), do: {:ok, query}

  defp apply_search(query, q, search_fields) when is_binary(q) do
    pattern = "%#{q}%"

    dynamic_expr =
      Enum.reduce(search_fields, dynamic(false), fn field_name, dynamic_expr ->
        dynamic([q], ^dynamic_expr or ilike(field(q, ^field_name), ^pattern))
      end)

    {:ok, from(q in query, where: ^dynamic_expr)}
  end

  defp apply_search(_query, _q, _search_fields), do: {:error, :bad_request}

  defp apply_filter(query, _queryable, _field, value) when value in [nil, ""], do: {:ok, query}

  defp apply_filter(query, queryable, field_name, value) do
    type = queryable.__schema__(:type, field_name)

    case type do
      :string ->
        pattern = "%#{value}%"
        {:ok, from(q in query, where: ilike(field(q, ^field_name), ^pattern))}

      :integer ->
        with {:ok, casted} <- Ecto.Type.cast(:integer, value) do
          {:ok, from(q in query, where: field(q, ^field_name) == ^casted)}
        else
          _ -> {:error, :bad_request}
        end

      :boolean ->
        with {:ok, casted} <- Ecto.Type.cast(:boolean, value) do
          {:ok, from(q in query, where: field(q, ^field_name) == ^casted)}
        else
          _ -> {:error, :bad_request}
        end

      _ ->
        with {:ok, casted} <- Ecto.Type.cast(type, value) do
          {:ok, from(q in query, where: field(q, ^field_name) == ^casted)}
        else
          _ -> {:error, :bad_request}
        end
    end
  end

  defp parse_sort(nil, _sortable, default_sort), do: {:ok, default_sort}
  defp parse_sort("", _sortable, default_sort), do: {:ok, default_sort}

  defp parse_sort(sort, sortable, _default_sort) when is_binary(sort) do
    case Enum.find(sortable, fn field -> Atom.to_string(field) == sort end) do
      nil -> {:error, :bad_request}
      field -> {:ok, field}
    end
  end

  defp parse_sort(sort, sortable, _default_sort) when is_atom(sort) do
    if sort in sortable, do: {:ok, sort}, else: {:error, :bad_request}
  end

  defp parse_sort(_sort, _sortable, _default_sort), do: {:error, :bad_request}

  defp parse_order(nil, default_order), do: {:ok, default_order}
  defp parse_order("", default_order), do: {:ok, default_order}
  defp parse_order(:asc, _default_order), do: {:ok, :asc}
  defp parse_order(:desc, _default_order), do: {:ok, :desc}

  defp parse_order(order, _default_order) when is_binary(order) do
    case String.downcase(order) do
      "asc" -> {:ok, :asc}
      "desc" -> {:ok, :desc}
      _ -> {:error, :bad_request}
    end
  end

  defp parse_order(_order, _default_order), do: {:error, :bad_request}

  defp parse_integer(nil, default, _opts), do: {:ok, default}
  defp parse_integer("", default, _opts), do: {:ok, default}

  defp parse_integer(value, _default, opts) when is_integer(value) do
    validate_integer(value, opts)
  end

  defp parse_integer(value, _default, opts) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> validate_integer(int, opts)
      _ -> {:error, :bad_request}
    end
  end

  defp parse_integer(_value, _default, _opts), do: {:error, :bad_request}

  defp validate_integer(value, opts) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    cond do
      is_integer(min) and value < min -> {:error, :bad_request}
      is_integer(max) and value > max -> {:error, :bad_request}
      true -> {:ok, value}
    end
  end

  defp to_filter_field(field, filterable) when is_atom(field) do
    if field in filterable, do: {:ok, field}, else: {:error, :bad_request}
  end

  defp to_filter_field(field, filterable) when is_binary(field) do
    case Enum.find(filterable, fn candidate -> Atom.to_string(candidate) == field end) do
      nil -> {:error, :bad_request}
      valid_field -> {:ok, valid_field}
    end
  end

  defp to_filter_field(_field, _filterable), do: {:error, :bad_request}

  defp total_pages(0, _per_page), do: 1
  defp total_pages(total_count, per_page), do: div(total_count + per_page - 1, per_page)

  defp maybe_preload(entries, []), do: entries
  defp maybe_preload(entries, preloads), do: Repo.preload(entries, preloads)

  defp param(params, key) when is_map(params), do: Map.get(params, key)
end
