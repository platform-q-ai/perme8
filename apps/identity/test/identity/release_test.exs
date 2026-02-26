defmodule Identity.ReleaseTest do
  use ExUnit.Case, async: true

  describe "Identity.Release" do
    test "migrate/0 is callable" do
      Code.ensure_loaded!(Identity.Release)
      assert function_exported?(Identity.Release, :migrate, 0)
    end

    test "rollback/2 is callable" do
      Code.ensure_loaded!(Identity.Release)
      assert function_exported?(Identity.Release, :rollback, 2)
    end

    test "repos/0 returns [Identity.Repo]" do
      assert Identity.Release.repos() == [Identity.Repo]
    end
  end
end
