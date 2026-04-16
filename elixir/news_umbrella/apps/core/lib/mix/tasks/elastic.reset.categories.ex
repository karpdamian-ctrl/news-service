defmodule Mix.Tasks.Elastic.Reset.Categories do
  use Mix.Task
  @shortdoc "Reset Elasticsearch index for /api/v1/categories"
  def run(_args), do: Core.Search.TaskRunner.run(:reset, :categories)
end
