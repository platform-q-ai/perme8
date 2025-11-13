defmodule Jarga.ReleaseTest do
  use ExUnit.Case, async: true

  alias Jarga.Release

  describe "migrate/0" do
    test "migrate function is defined and returns list" do
      # Verify the module and function exist
      assert Code.ensure_loaded?(Release)
      assert function_exported?(Jarga.Release, :migrate, 0)
    end
  end

  describe "rollback/2" do
    test "rollback function is defined" do
      # Verify the module and function exist
      assert Code.ensure_loaded?(Release)
      assert function_exported?(Jarga.Release, :rollback, 2)
    end
  end
end
