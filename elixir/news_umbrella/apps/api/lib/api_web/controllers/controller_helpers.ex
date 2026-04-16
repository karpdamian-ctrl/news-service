defmodule ApiWeb.ControllerHelpers do
  @moduledoc false

  def parse_int_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  def parse_int_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, :bad_request}
    end
  end

  def parse_int_id(_), do: {:error, :bad_request}

  def fetch_or_not_found(nil), do: {:error, :not_found}
  def fetch_or_not_found(struct), do: {:ok, struct}

  def collection_response(entries, serializer, meta) when is_function(serializer, 1) do
    %{
      data: Enum.map(entries, serializer),
      meta: meta
    }
  end
end
