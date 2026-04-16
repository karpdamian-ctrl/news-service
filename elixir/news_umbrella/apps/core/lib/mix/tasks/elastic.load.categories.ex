defmodule Mix.Tasks.Elastic.Load.Categories do
  use Mix.Task
  @shortdoc "Load Elasticsearch documents for /api/v1/categories"
  def run(_args), do: Core.Search.TaskRunner.run(:load, :categories)
end
