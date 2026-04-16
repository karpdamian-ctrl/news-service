defmodule Mix.Tasks.Elastic.Load.Articles do
  use Mix.Task
  @shortdoc "Load Elasticsearch documents for /api/v1/articles"
  def run(_args), do: Core.Search.TaskRunner.run(:load, :articles)
end
