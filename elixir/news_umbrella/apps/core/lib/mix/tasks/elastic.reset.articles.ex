defmodule Mix.Tasks.Elastic.Reset.Articles do
  use Mix.Task
  @shortdoc "Reset Elasticsearch index for /api/v1/articles"
  def run(_args), do: Core.Search.TaskRunner.run(:reset, :articles)
end
