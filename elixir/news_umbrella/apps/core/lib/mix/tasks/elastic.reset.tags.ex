defmodule Mix.Tasks.Elastic.Reset.Tags do
  use Mix.Task
  @shortdoc "Reset Elasticsearch index for /api/v1/tags"
  def run(_args), do: Core.Search.TaskRunner.run(:reset, :tags)
end
