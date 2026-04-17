defmodule Core.Search.NoopEvents do
  @moduledoc false

  def publish(_event), do: :ok
end

