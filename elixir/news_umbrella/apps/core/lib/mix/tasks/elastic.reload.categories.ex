defmodule Mix.Tasks.Elastic.Reload.Categories do
  use Mix.Task
  @shortdoc "Reload Elasticsearch index and data for /api/v1/categories"
  def run(_args), do: Core.Search.TaskRunner.run(:reload, :categories)
end
