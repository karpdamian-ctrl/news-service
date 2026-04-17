defmodule Core.ContentRenderer.QueuePublisher do
  @moduledoc false

  @default_queue "news.article_markdown.render"

  def publish_article(article_id) when is_integer(article_id) and article_id > 0 do
    rabbitmq_url = rabbitmq_url()
    queue = queue_name()
    payload = Jason.encode!(%{article_id: article_id})

    case AMQP.Connection.open(rabbitmq_url) do
      {:ok, conn} ->
        result =
          with {:ok, channel} <- AMQP.Channel.open(conn) do
            publish(channel, queue, payload)
          end

        _ = AMQP.Connection.close(conn)

        case result do
          :ok ->
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def publish_article(_), do: {:error, :invalid_article_id}

  defp publish(channel, queue, payload) do
    result =
      with {:ok, _} <- AMQP.Queue.declare(channel, queue, durable: true),
           :ok <-
             AMQP.Basic.publish(channel, "", queue, payload,
               persistent: true,
               content_type: "application/json"
             ) do
        :ok
      end

    _ = AMQP.Channel.close(channel)
    result
  end

  defp queue_name do
    Application.get_env(:core, Core.ContentRenderer.QueueConsumer, [])
    |> Keyword.get(:queue, @default_queue)
  end

  defp rabbitmq_url do
    Application.get_env(:core, :integrations, [])
    |> Keyword.get(:rabbitmq_url, "amqp://news:news@localhost:5672")
  end
end
