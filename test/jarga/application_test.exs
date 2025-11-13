defmodule Jarga.ApplicationTest do
  use ExUnit.Case, async: true

  describe "Application" do
    test "config_change/3 returns :ok" do
      assert :ok = JargaApp.config_change([], [], [])
    end
  end
end
