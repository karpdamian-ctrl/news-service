defmodule Mix.Tasks.Elastic.Load.Media do
  use Mix.Task
  @shortdoc "Load Elasticsearch documents for /api/v1/media"
  def run(_args), do: Core.Search.TaskRunner.run(:load, :media)
end
