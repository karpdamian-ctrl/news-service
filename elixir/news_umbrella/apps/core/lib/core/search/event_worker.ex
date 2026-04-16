defmodule Core.Search.EventWorker do
  @moduledoc false

  use GenServer
  require Logger

  alias Core.Search.EventProcessor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:event, event}, state) do
    Task.Supervisor.start_child(Core.Search.TaskSupervisor, fn ->
      case EventProcessor.process(event) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("ELASTIC_EVENT_FAILED #{inspect(%{event: event, reason: reason})}")
      end
    end)

    {:noreply, state}
  end
end
