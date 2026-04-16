defmodule Core.Search.TaskRunner do
  @moduledoc false

  alias Core.Search.Indexer

  @spec run(:reset | :load | :reload, atom()) :: :ok | no_return()
  def run(action, resource) when action in [:reset, :load, :reload] and is_atom(resource) do
    Mix.Task.run("app.start")

    case execute(action, resource) do
      :ok ->
        Mix.shell().info("elasticsearch #{action} finished for #{resource}")
        :ok

      {:ok, %{indexed_count: count, index: index}} ->
        Mix.shell().info(
          "elasticsearch #{action} finished for #{resource}: indexed=#{count}, index=#{index}"
        )

        :ok

      {:error, reason} ->
        Mix.raise("elasticsearch #{action} failed for #{resource}: #{inspect(reason)}")
    end
  end

  defp execute(:reset, resource), do: Indexer.reset_resource(resource)
  defp execute(:load, resource), do: Indexer.load_resource(resource)
  defp execute(:reload, resource), do: Indexer.reindex_resource(resource)
end
