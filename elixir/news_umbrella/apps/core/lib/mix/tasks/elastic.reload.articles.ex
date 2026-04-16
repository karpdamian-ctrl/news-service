defmodule Mix.Tasks.Elastic.Reload.Articles do
  use Mix.Task
  @shortdoc "Reload Elasticsearch index and data for /api/v1/articles"
  def run(_args), do: Core.Search.TaskRunner.run(:reload, :articles)
end
