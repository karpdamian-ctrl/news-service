defmodule Mix.Tasks.Elastic.Reload.All do
  use Mix.Task

  @shortdoc "Recreate and load Elasticsearch indexes for all API resources"

  def run(_args) do
    Mix.Task.run("app.start")

    Core.Search.Documents.resources()
    |> Enum.each(fn resource ->
      case Core.Search.Indexer.reindex_resource(resource) do
        {:ok, %{indexed_count: count, index: index}} ->
          Mix.shell().info(
            "elasticsearch reload finished for #{resource}: indexed=#{count}, index=#{index}"
          )

        {:error, reason} ->
          Mix.raise("elasticsearch reload failed for #{resource}: #{inspect(reason)}")
      end
    end)
  end
end
