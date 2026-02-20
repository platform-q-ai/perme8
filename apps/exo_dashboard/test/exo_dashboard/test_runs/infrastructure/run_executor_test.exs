defmodule ExoDashboard.TestRuns.Infrastructure.RunExecutorTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Infrastructure.RunExecutor

  defmodule MockFileSystem do
    def mkdir_p!(_path), do: :ok
  end

  defmodule TrackingFileSystem do
    def mkdir_p!(path) do
      send(:run_executor_test, {:mkdir_p!, path})
      :ok
    end
  end

  describe "start/2" do
    @tag :external
    test "spawns a task and returns {:ok, pid}" do
      {:ok, pid} =
        RunExecutor.start("test-run-1",
          scope: {:app, "jarga_web"},
          file_system: MockFileSystem
        )

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "calls mkdir_p! on the file_system module" do
      Process.register(self(), :run_executor_test)

      {:ok, _pid} =
        RunExecutor.start("test-run-2",
          scope: {:app, "jarga_web"},
          file_system: TrackingFileSystem
        )

      assert_receive {:mkdir_p!, "/tmp/exo_dashboard"}, 2000
    after
      try do
        Process.unregister(:run_executor_test)
      rescue
        _ -> :ok
      end
    end
  end

  describe "build_args/2" do
    test "builds correct bun args for app scope" do
      args = RunExecutor.build_args("run-1", scope: {:app, "jarga_web"})

      assert "--tags" in args
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
