defmodule Core.Search.Searcher do
  @moduledoc false

  alias Core.Search.Documents
  require Logger

  @default_page 1
  @default_per_page 20
  @max_per_page 100
  @default_terms_limit 5
  @max_terms_limit 50
  @default_timeout 15_000

  def search_documents(resource, params, opts \\ []) when is_atom(resource) and is_map(params) do
    definition = Documents.definition!(resource)
    page = parse_positive_int(Map.get(params, "page"), @default_page)

    per_page =
      parse_positive_int(Map.get(params, "per_page"), @default_per_page) |> min(@max_per_page)

    from = (page - 1) * per_page
    q = parse_query(Map.get(params, "q"))

    body = %{
      from: from,
      size: per_page,
      track_total_hits: true,
      query: build_query(q, Map.get(params, "filter"), definition),
      sort: build_sort(q, params, definition)
    }

    with {:ok, %{status: 200, body: response_body}} <-
           request(:post, "/#{definition.index}/_search", body, opts),
         {:ok, %{documents: documents, total_count: total_count, took_ms: took_ms}} <-
           parse_response(response_body) do
      {:ok,
       %{
         documents: documents,
         meta: %{
           page: page,
           per_page: per_page,
           total_count: total_count,
           total_pages: total_pages(total_count, per_page),
           has_prev_page: page > 1,
           has_next_page: page < total_pages(total_count, per_page),
           query: q,
           source: "elasticsearch",
           took_ms: took_ms
         }
       }}
    else
      {:ok, %{status: _status, body: _body}} -> {:error, :search_unavailable}
      {:error, _reason} -> {:error, :search_unavailable}
    end
  end

  def top_terms(resource, field, params \\ %{}, opts \\ [])
      when is_atom(resource) and is_binary(field) and is_map(params) do
    definition = Documents.definition!(resource)

    limit =
      parse_positive_int(Map.get(params, "limit"), @default_terms_limit) |> min(@max_terms_limit)

    q = parse_query(Map.get(params, "q"))

    body = %{
      size: 0,
      query: build_query(q, Map.get(params, "filter"), definition),
      aggs: %{
        "top_terms" => %{
          terms: %{
            field: field,
            size: limit,
            order: %{"_count" => "desc"},
            min_doc_count: 1
          }
        }
      }
    }

    with {:ok, %{status: 200, body: response_body}} <-
           request(:post, "/#{definition.index}/_search", body, opts),
         {:ok, %{terms: terms, took_ms: took_ms}} <- parse_terms_response(response_body) do
      {:ok, %{terms: terms, meta: %{limit: limit, source: "elasticsearch", took_ms: took_ms}}}
    else
      {:ok, %{status: _status, body: _body}} -> {:error, :search_unavailable}
      {:error, _reason} -> {:error, :search_unavailable}
    end
  end

  defp request(method, path, body, opts) do
    client =
      Keyword.get(
        opts,
        :http_client,
        Application.get_env(:core, :search_http_client, Core.Search.HTTP.ReqClient)
      )

    url = elasticsearch_url(opts) <> path
    headers = [{"content-type", "application/json"}]
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    started_at = System.monotonic_time(:millisecond)

    Logger.info(
      "ELASTIC_REQUEST #{inspect(%{method: method, url: url, timeout_ms: timeout, body: body})}"
    )

    result = client.request(method, url, headers, body, timeout: timeout)
    duration_ms = System.monotonic_time(:millisecond) - started_at

    case result do
      {:ok, %{status: status}} ->
        Logger.info(
          "ELASTIC_RESPONSE #{inspect(%{method: method, url: url, status: status, duration_ms: duration_ms})}"
        )

      {:error, reason} ->
        Logger.warning(
          "ELASTIC_RESPONSE #{inspect(%{method: method, url: url, error: reason, duration_ms: duration_ms})}"
        )
    end

    result
  end

  defp parse_response(%{"hits" => %{"hits" => hits}, "took" => took} = body) when is_list(hits) do
    total = total_hits(body)

    docs =
      Enum.map(hits, fn hit ->
        source = hit["_source"] || %{}

        source
        |> ensure_hit_id(hit["_id"])
        |> ensure_score(hit["_score"])
      end)

    {:ok, %{documents: docs, total_count: total, took_ms: took}}
  end

  defp parse_response(%{hits: %{hits: hits}, took: took} = body) when is_list(hits) do
    total = total_hits(body)

    docs =
      Enum.map(hits, fn hit ->
        source = hit[:_source] || %{}

        source
        |> ensure_hit_id(hit[:_id])
        |> ensure_score(hit[:_score])
      end)

    {:ok, %{documents: docs, total_count: total, took_ms: took}}
  end

  defp parse_response(_), do: {:error, :invalid_search_response}

  defp parse_terms_response(%{
         "aggregations" => %{"top_terms" => %{"buckets" => buckets}},
         "took" => took
       })
       when is_list(buckets) do
    terms =
      Enum.map(buckets, fn bucket ->
        %{
          term: bucket["key"],
          count: bucket["doc_count"]
        }
      end)

    {:ok, %{terms: terms, took_ms: took}}
  end

  defp parse_terms_response(%{
         aggregations: %{"top_terms" => %{"buckets" => buckets}},
         took: took
       })
       when is_list(buckets) do
    terms =
      Enum.map(buckets, fn bucket ->
        %{
          term: bucket["key"],
          count: bucket["doc_count"]
        }
      end)

    {:ok, %{terms: terms, took_ms: took}}
  end

  defp parse_terms_response(%{aggregations: %{top_terms: %{buckets: buckets}}, took: took})
       when is_list(buckets) do
    terms =
      Enum.map(buckets, fn bucket ->
        %{
          term: bucket[:key],
          count: bucket[:doc_count]
        }
      end)

    {:ok, %{terms: terms, took_ms: took}}
  end

  defp parse_terms_response(_), do: {:error, :invalid_search_response}

  defp ensure_hit_id(doc, nil), do: doc

  defp ensure_hit_id(doc, id) do
    if Map.has_key?(doc, "id") || Map.has_key?(doc, :id) do
      doc
    else
      case Integer.parse(to_string(id)) do
        {int, ""} -> Map.put(doc, "id", int)
        _ -> Map.put(doc, "id", id)
      end
    end
  end

  defp ensure_score(doc, nil), do: doc
  defp ensure_score(doc, score), do: Map.put(doc, "_score", score)

  defp total_hits(%{"hits" => %{"total" => %{"value" => value}}}) when is_integer(value),
    do: value

  defp total_hits(%{hits: %{total: %{value: value}}}) when is_integer(value), do: value
  defp total_hits(%{"hits" => %{"total" => value}}) when is_integer(value), do: value
  defp total_hits(%{hits: %{total: value}}) when is_integer(value), do: value
  defp total_hits(_), do: 0

  defp build_query(q, filter_params, definition) do
    must =
      []
      |> maybe_add_text_query(q, definition)
      |> maybe_add_filters(filter_params, definition)

    case must do
      [] -> %{match_all: %{}}
      clauses -> %{bool: %{must: clauses}}
    end
  end

  defp maybe_add_text_query(must, nil, _definition), do: must
  defp maybe_add_text_query(must, "", _definition), do: must

  defp maybe_add_text_query(must, q, definition) do
    fields = search_fields(definition)

    [
      %{
        multi_match: %{
          query: q,
          fields: fields,
          type: "best_fields",
          operator: "and"
        }
      }
      | must
    ]
  end

  defp maybe_add_filters(must, nil, _definition), do: must

  defp maybe_add_filters(must, %{} = filters, definition),
    do: Enum.reduce(filters, must, &build_filter_clause(&1, &2, definition))

  defp maybe_add_filters(must, _filters, _definition), do: must

  defp build_filter_clause({field, raw_value}, acc, definition) do
    field_name = to_string(field)

    if field_name in filterable_fields(definition) do
      clause =
        case normalize_filter_value(raw_value) do
          [] -> nil
          values when is_list(values) -> %{terms: %{field_name => values}}
          value -> %{term: %{field_name => value}}
        end

      if is_nil(clause), do: acc, else: [clause | acc]
    else
      acc
    end
  end

  defp build_sort(q, params, definition) do
    sort = Map.get(params, "sort")
    order = normalize_sort_order(Map.get(params, "order"))

    cond do
      is_binary(sort) and sort in sortable_fields(definition) ->
        [%{sort => %{order: order}}]

      q in [nil, ""] ->
        [%{id: %{order: "desc"}}]

      true ->
        [%{_score: %{order: "desc"}}, %{id: %{order: "desc"}}]
    end
  end

  defp search_fields(definition) do
    case Map.get(definition, :search_fields) do
      fields when is_list(fields) and fields != [] ->
        fields

      _ ->
        text_mapping_fields(definition)
    end
  end

  defp filterable_fields(definition) do
    case Map.get(definition, :filterable_fields) do
      fields when is_list(fields) -> Enum.map(fields, &to_string/1)
      _ -> default_mapping_fields(definition)
    end
  end

  defp sortable_fields(definition) do
    case Map.get(definition, :sortable_fields) do
      fields when is_list(fields) -> Enum.map(fields, &to_string/1)
      _ -> default_mapping_fields(definition)
    end
  end

  defp default_mapping_fields(definition) do
    definition
    |> mapping_properties()
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end

  defp text_mapping_fields(definition) do
    definition
    |> mapping_properties()
    |> Enum.filter(fn {_field, config} ->
      case config do
        %{"type" => "text"} -> true
        %{type: "text"} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {field, _} -> to_string(field) end)
    |> case do
      [] -> ["*"]
      fields -> fields
    end
  end

  defp mapping_properties(definition) do
    case Map.get(definition, :mappings) do
      %{"properties" => props} when is_map(props) -> props
      %{properties: props} when is_map(props) -> props
      _ -> %{}
    end
  end

  defp normalize_filter_value(values) when is_list(values),
    do: Enum.map(values, &normalize_filter_value/1)

  defp normalize_filter_value(values) when is_map(values) do
    values
    |> map_values_as_list()
    |> Enum.map(&normalize_filter_value/1)
    |> Enum.reject(&(&1 in [nil, "", []]))
  end

  defp normalize_filter_value(value) when is_boolean(value), do: value
  defp normalize_filter_value(value) when is_integer(value), do: value

  defp normalize_filter_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> trimmed
      String.downcase(trimmed) == "true" -> true
      String.downcase(trimmed) == "false" -> false
      Regex.match?(~r/^-?\d+$/, trimmed) -> String.to_integer(trimmed)
      true -> trimmed
    end
  end

  defp normalize_filter_value(value), do: value

  defp map_values_as_list(map) do
    if Enum.all?(map, fn {key, _} -> integerish_key?(key) end) do
      map
      |> Enum.sort_by(fn {key, _} -> parse_integerish_key(key) end)
      |> Enum.map(fn {_key, value} -> value end)
    else
      map |> Map.values()
    end
  end

  defp integerish_key?(key) when is_integer(key), do: true

  defp integerish_key?(key) when is_binary(key) do
    case Integer.parse(key) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp integerish_key?(_), do: false

  defp parse_integerish_key(key) when is_integer(key), do: key

  defp parse_integerish_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {value, ""} -> value
      _ -> 0
    end
  end

  defp parse_integerish_key(_), do: 0

  defp normalize_sort_order(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "asc" -> "asc"
      _ -> "desc"
    end
  end

  defp normalize_sort_order(_), do: "desc"

  defp parse_query(nil), do: nil
  defp parse_query(value) when is_binary(value), do: String.trim(value)
  defp parse_query(value), do: to_string(value)

  defp parse_positive_int(nil, default), do: default
  defp parse_positive_int("", default), do: default
  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default

  defp total_pages(0, _per_page), do: 1
  defp total_pages(total_count, per_page), do: div(total_count + per_page - 1, per_page)

  defp elasticsearch_url(opts) do
    case Keyword.get(opts, :base_url) do
      nil ->
        Application.get_env(:core, :integrations, [])
        |> Keyword.get(:elasticsearch_url, "http://localhost:9200")
        |> String.trim_trailing("/")

      value ->
        value |> to_string() |> String.trim_trailing("/")
    end
  end
end
