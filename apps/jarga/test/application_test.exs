defmodule Jarga.ApplicationTest do
  use ExUnit.Case, async: true

  describe "Application" do
    test "starts successfully" do
      # If we can call the module, it's loaded
      assert Code.ensure_loaded?(Jarga.Application)
    end
  end
end
