defmodule ArticlesGeneratorTest do
  use ExUnit.Case
  doctest ArticlesGenerator

  test "returns random delay in required range" do
    Enum.each(1..50, fn _ ->
      delay = ArticlesGenerator.next_delay_seconds()
      assert delay >= 180
      assert delay <= 360
    end)
  end
end
