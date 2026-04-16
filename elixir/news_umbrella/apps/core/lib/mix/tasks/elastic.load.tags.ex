defmodule Mix.Tasks.Elastic.Load.Tags do
  use Mix.Task
  @shortdoc "Load Elasticsearch documents for /api/v1/tags"
  def run(_args), do: Core.Search.TaskRunner.run(:load, :tags)
end
