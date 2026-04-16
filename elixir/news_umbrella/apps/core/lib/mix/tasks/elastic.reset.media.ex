defmodule Mix.Tasks.Elastic.Reset.Media do
  use Mix.Task
  @shortdoc "Reset Elasticsearch index for /api/v1/media"
  def run(_args), do: Core.Search.TaskRunner.run(:reset, :media)
end
