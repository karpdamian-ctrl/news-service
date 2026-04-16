defmodule Mix.Tasks.Elastic.Load.ArticleRevisions do
  use Mix.Task
  @shortdoc "Load Elasticsearch documents for /api/v1/article-revisions"
  def run(_args), do: Core.Search.TaskRunner.run(:load, :article_revisions)
end
