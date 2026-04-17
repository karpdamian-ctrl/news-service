defmodule Core.ContentRenderer.QueueConsumer do
  @moduledoc false

  use GenServer
  require Logger

  alias Core.ContentRenderer.MarkdownProcessor

  @default_queue "news.article_markdown.render"
  @default_reconnect_ms 5_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    state = %{
      connection: nil,
      channel: nil,
      queue: queue_name(),
      reconnect_ms: reconnect_ms(),
      rabbitmq_url: rabbitmq_url()
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect(state) do
      {:ok, next_state} ->
        {:noreply, next_state}

      {:error, reason} ->
        Logger.warning("ARTICLE_RENDER_CONSUMER_CONNECT_FAILED #{inspect(reason)}")
        Process.send_after(self(), :connect, state.reconnect_ms)
        {:noreply, state}
    end
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state), do: {:noreply, state}
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state), do: {:noreply, state}

  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("ARTICLE_RENDER_CONSUMER_CANCELLED")
    Process.send_after(self(), :connect, state.reconnect_ms)
    {:noreply, drop_connection(state)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("ARTICLE_RENDER_CONSUMER_DOWN #{inspect(reason)}")
    Process.send_after(self(), :connect, state.reconnect_ms)
    {:noreply, drop_connection(state)}
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    result = MarkdownProcessor.process_payload(payload)

    case result do
      :ok ->
        :ok = AMQP.Basic.ack(state.channel, meta.delivery_tag)

      {:error, reason} ->
        Logger.warning(
          "ARTICLE_RENDER_PROCESS_FAILED #{inspect(%{reason: reason, payload: payload})}"
        )

        :ok = AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
    end

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    close_state(state)
    :ok
  end

  defp connect(state) do
    with {:ok, conn} <- AMQP.Connection.open(state.rabbitmq_url),
         {:ok, channel} <- AMQP.Channel.open(conn),
         {:ok, _} <- AMQP.Queue.declare(channel, state.queue, durable: true),
         :ok <- AMQP.Basic.qos(channel, prefetch_count: 10),
         {:ok, _consumer_tag} <- AMQP.Basic.consume(channel, state.queue) do
      Process.monitor(conn.pid)
      Process.monitor(channel.pid)
      Logger.info("ARTICLE_RENDER_CONSUMER_CONNECTED #{inspect(%{queue: state.queue})}")
      {:ok, %{state | connection: conn, channel: channel}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp drop_connection(state) do
    close_state(state)
    %{state | connection: nil, channel: nil}
  end

  defp close_state(state) do
    safe_close_channel(state.channel)
    safe_close_connection(state.connection)
  end

  defp safe_close_channel(nil), do: :ok

  defp safe_close_channel(channel) do
    _ = AMQP.Channel.close(channel)
    :ok
  rescue
    _ -> :ok
  end

  defp safe_close_connection(nil), do: :ok

  defp safe_close_connection(connection) do
    _ = AMQP.Connection.close(connection)
    :ok
  rescue
    _ -> :ok
  end

  defp queue_name do
    Application.get_env(:core, __MODULE__, [])
    |> Keyword.get(:queue, @default_queue)
  end

  defp reconnect_ms do
    Application.get_env(:core, __MODULE__, [])
    |> Keyword.get(:reconnect_ms, @default_reconnect_ms)
  end

  defp rabbitmq_url do
    Application.get_env(:core, :integrations, [])
    |> Keyword.get(:rabbitmq_url, "amqp://news:news@localhost:5672")
  end
end
