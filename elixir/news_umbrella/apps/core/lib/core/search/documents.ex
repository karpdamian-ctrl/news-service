defmodule Core.Search.Documents do
  @moduledoc false

  @type resource :: :categories | :tags | :media | :articles | :article_revisions

  @type definition :: %{
          required(:endpoint) => String.t(),
          required(:index) => String.t(),
          required(:source) => {module(), atom()},
          required(:settings) => map(),
          required(:mappings) => map()
        }

  @spec resources() :: [resource()]
  def resources do
    definitions()
    |> Map.keys()
    |> Enum.sort()
  end

  @spec definition!(resource()) :: definition()
  def definition!(resource) when is_atom(resource) do
    case Map.fetch(definitions(), resource) do
      {:ok, definition} ->
        validate_definition!(resource, definition)

      :error ->
        raise ArgumentError,
              "unknown elasticsearch resource #{inspect(resource)}. Available: #{inspect(resources())}"
    end
  end

  @spec definitions() :: %{resource() => definition()}
  def definitions do
    case Application.fetch_env!(:core, :elastic_documents) do
      value when is_map(value) -> value
      value when is_list(value) -> Map.new(value)
    end
  end

  defp validate_definition!(resource, definition) do
    required = [:endpoint, :index, :source, :settings, :mappings]

    Enum.each(required, fn key ->
      if Map.get(definition, key) in [nil, ""] do
        raise ArgumentError,
              "invalid elasticsearch definition for #{inspect(resource)}: missing #{inspect(key)}"
      end
    end)

    case definition.source do
      {module, function} when is_atom(module) and is_atom(function) ->
        :ok

      _ ->
        raise ArgumentError,
              "invalid source in elasticsearch definition for #{inspect(resource)}. Expected {Module, :function}"
    end

    validate_string_list!(resource, definition, :search_fields)
    validate_string_list!(resource, definition, :filterable_fields)
    validate_string_list!(resource, definition, :sortable_fields)

    definition
  end

  defp validate_string_list!(resource, definition, key) do
    case Map.get(definition, key) do
      nil ->
        :ok

      value when is_list(value) ->
        if Enum.all?(value, &is_binary/1) do
          :ok
        else
          raise ArgumentError,
                "invalid #{inspect(key)} in elasticsearch definition for #{inspect(resource)}. Expected list of strings"
        end

      _ ->
        raise ArgumentError,
              "invalid #{inspect(key)} in elasticsearch definition for #{inspect(resource)}. Expected list of strings"
    end
  end
end
