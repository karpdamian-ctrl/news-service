defmodule Mix.Tasks.Elastic.Reset.All do
  use Mix.Task

  @shortdoc "Reset Elasticsearch indexes for all API resources"

  def run(_args) do
    Mix.Task.run("app.start")

    Core.Search.Documents.resources()
    |> Enum.each(fn resource ->
      case Core.Search.Indexer.reset_resource(resource) do
        :ok ->
          Mix.shell().info("elasticsearch reset finished for #{resource}")

        {:error, reason} ->
          Mix.raise("elasticsearch reset failed for #{resource}: #{inspect(reason)}")
      end
    end)
  end
end
