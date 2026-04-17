defmodule Core.ContentRenderer.NoopQueuePublisher do
  @moduledoc false

  def publish_article(_article_id), do: :ok
end
