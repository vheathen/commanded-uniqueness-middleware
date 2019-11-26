defmodule Commanded.Middleware.UniquenessTest do
  use ExUnit.Case
  doctest Commanded.Middleware.Uniqueness

  test "greets the world" do
    assert Commanded.Middleware.Uniqueness.hello() == :world
  end
end
