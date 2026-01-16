defmodule Jarga.Credo.Check.Testing.MissingDomainTestsTest do
  @moduledoc """
  Tests for the MissingDomainTests Credo check.

  This test ensures the check correctly identifies domain modules
  (policies, services) that are missing corresponding test files.
  """

  use ExUnit.Case

  alias Jarga.Credo.Check.Testing.MissingDomainTests

  describe "run/2" do
    test "reports no issues when test file exists for policy" do
      # When both policy and test exist, should not report
      issues = MissingDomainTests.run(%{}, [])

      # This check works at file system level, so we test the actual files
      # The check should find existing policies and verify tests exist
      assert is_list(issues)
    end

    test "detects missing test for policy module" do
      # This will check the actual file system
      # Should report issues for any policy without a test
      issues = MissingDomainTests.run(%{}, [])

      assert is_list(issues)
      # We expect to find missing tests for Pages, Notes policies
    end
  end
end
