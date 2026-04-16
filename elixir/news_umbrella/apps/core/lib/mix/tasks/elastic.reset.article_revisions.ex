defmodule Mix.Tasks.Elastic.Reset.ArticleRevisions do
  use Mix.Task
  @shortdoc "Reset Elasticsearch index for /api/v1/article-revisions"
  def run(_args), do: Core.Search.TaskRunner.run(:reset, :article_revisions)
end
