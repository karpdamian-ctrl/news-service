defmodule Core.Search.Events do
  @moduledoc false

  def publish(event) do
    GenServer.cast(Core.Search.EventWorker, {:event, event})
    :ok
  end
end
