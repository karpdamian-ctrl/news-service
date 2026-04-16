defmodule Mix.Tasks.Elastic.Reload.ArticleRevisions do
  use Mix.Task
  @shortdoc "Reload Elasticsearch index and data for /api/v1/article-revisions"
  def run(_args), do: Core.Search.TaskRunner.run(:reload, :article_revisions)
end
