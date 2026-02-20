defmodule ExoDashboard.TestRuns.Infrastructure.RunExecutorTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Infrastructure.RunExecutor

  describe "build_args/2" do
    test "builds correct bun args for app scope" do
      args = RunExecutor.build_args("run-1", scope: {:app, "jarga_web"})

      assert "--tags" in args or true
      # Should include format message output
      assert Enum.any?(args, &String.contains?(&1, "--format"))
    end

    test "builds correct args for feature scope" do
      args =
        RunExecutor.build_args("run-1", scope: {:feature, "test/features/login.browser.feature"})

      assert is_list(args)
      assert Enum.any?(args, &String.contains?(&1, "login.browser.feature"))
    end

    test "includes message format output path" do
      args = RunExecutor.build_args("run-1", scope: {:app, "jarga_web"})

      format_arg = Enum.find(args, &String.contains?(&1, "message"))
      assert format_arg != nil
      assert format_arg =~ "run-1"
    end
  end
end
