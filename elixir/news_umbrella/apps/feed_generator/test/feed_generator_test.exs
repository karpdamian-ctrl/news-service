defmodule FeedGeneratorTest do
  use ExUnit.Case
  doctest FeedGenerator

  test "greets the world" do
    assert FeedGenerator.hello() == :world
  end
end
