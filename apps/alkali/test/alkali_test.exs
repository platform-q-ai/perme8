defmodule AlkaliTest do
  use ExUnit.Case
  doctest Alkali

  test "greets the world" do
    assert Alkali.hello() == :world
  end
end
