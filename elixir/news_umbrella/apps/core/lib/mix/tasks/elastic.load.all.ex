defmodule Mix.Tasks.Elastic.Load.All do
  use Mix.Task

  @shortdoc "Load Elasticsearch documents for all API resources"

  def run(_args) do
    Mix.Task.run("app.start")

    Core.Search.Documents.resources()
    |> Enum.each(fn resource ->
      case Core.Search.Indexer.load_resource(resource) do
        {:ok, %{indexed_count: count, index: index}} ->
          Mix.shell().info(
            "elasticsearch load finished for #{resource}: indexed=#{count}, index=#{index}"
          )

        {:error, reason} ->
          Mix.raise("elasticsearch load failed for #{resource}: #{inspect(reason)}")
      end
    end)
  end
end
