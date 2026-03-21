defmodule Agents.Pipeline.Infrastructure.GitDiffComputerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.GitDiffComputer

  defmodule CommandRunnerStub do
    def run(command, opts) do
      Process.get({__MODULE__, :run}).(command, opts)
    end
  end

  test "computes diff from git command output" do
    Process.put({CommandRunnerStub, :run}, fn command, _opts ->
      assert command == ["git", "diff", "main...feature/x"]
      {0, "diff --git a/x b/x", ""}
    end)

    assert {:ok, diff} =
             GitDiffComputer.compute_diff("feature/x", "main", command_runner: CommandRunnerStub)

    assert diff =~ "diff --git"
  end

  test "returns error tuple when command fails" do
    Process.put({CommandRunnerStub, :run}, fn _command, _opts ->
      {1, "", "fatal: bad revision"}
    end)

    assert {:error, {:git_diff_failed, "fatal: bad revision"}} =
             GitDiffComputer.compute_diff("feature/x", "main", command_runner: CommandRunnerStub)
  end
end
