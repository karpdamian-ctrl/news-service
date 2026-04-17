defmodule ArticlesGenerator do
  @moduledoc """
  Helpers for automated article generation.
  """

  @min_interval_seconds 180
  @max_interval_seconds 360

  @doc """
  Returns a random delay in seconds between 3 and 6 minutes.
  """
  def next_delay_seconds(min_seconds \\ @min_interval_seconds, max_seconds \\ @max_interval_seconds) do
    range = max_seconds - min_seconds + 1
    min_seconds + :rand.uniform(range) - 1
  end
end
