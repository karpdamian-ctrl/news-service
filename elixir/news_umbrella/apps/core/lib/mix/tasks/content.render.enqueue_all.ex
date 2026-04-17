defmodule Mix.Tasks.Content.Render.EnqueueAll do
  use Mix.Task

  import Ecto.Query, only: [from: 2]

  @shortdoc "Enqueue all articles for markdown -> HTML rendering"

  alias Core.News.Article
  alias Core.Repo

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    publisher_module =
      Application.get_env(
        :core,
        :article_render_queue_publisher_module,
        Core.ContentRenderer.QueuePublisher
      )

    article_ids =
      from(a in Article, order_by: [asc: a.id], select: a.id)
      |> Repo.all()

    {ok_count, error_count} =
      Enum.reduce(article_ids, {0, 0}, fn article_id, {ok_acc, err_acc} ->
        case publisher_module.publish_article(article_id) do
          :ok ->
            {ok_acc + 1, err_acc}

          {:error, reason} ->
            Mix.shell().error(
              "content.render.enqueue_all: enqueue failed for article_id=#{article_id} reason=#{inspect(reason)}"
            )

            {ok_acc, err_acc + 1}
        end
      end)

    Mix.shell().info(
      "content.render.enqueue_all finished: total=#{length(article_ids)} queued=#{ok_count} failed=#{error_count}"
    )
  end
end
