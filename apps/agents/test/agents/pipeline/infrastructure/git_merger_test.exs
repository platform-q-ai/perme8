defmodule Agents.Pipeline.Infrastructure.GitMergerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.GitMerger

  defmodule CommandRunnerStub do
    def run(command, opts) do
      Process.get({__MODULE__, :run}).(command, opts)
    end
  end

  test "checks out target branch, merges, and pushes for merge method" do
    parent = self()

    Process.put({CommandRunnerStub, :run}, fn command, _opts ->
      send(parent, {:command, command})
      {0, "", ""}
    end)

    assert :ok = GitMerger.merge("feature/x", "main", "merge", command_runner: CommandRunnerStub)

    assert_received {:command, ["git", "checkout", "main"]}
    assert_received {:command, ["git", "merge", "--no-ff", "feature/x"]}
    assert_received {:command, ["git", "push", "origin", "main"]}
  end

  test "returns error when merge command fails" do
    Process.put({CommandRunnerStub, :run}, fn command, _opts ->
      case command do
        ["git", "checkout", "main"] -> {0, "", ""}
        ["git", "merge", "--no-ff", "feature/x"] -> {1, "", "conflict"}
      end
    end)

    assert {:error, {:git_merge_failed, "conflict"}} =
             GitMerger.merge("feature/x", "main", "merge", command_runner: CommandRunnerStub)
  end

  test "returns error when push command fails" do
    Process.put({CommandRunnerStub, :run}, fn command, _opts ->
      case command do
        ["git", "checkout", "main"] -> {0, "", ""}
        ["git", "merge", "--no-ff", "feature/x"] -> {0, "", ""}
        ["git", "push", "origin", "main"] -> {1, "", "rejected"}
      end
    end)

    assert {:error, {:git_push_failed, "rejected"}} =
             GitMerger.merge("feature/x", "main", "merge", command_runner: CommandRunnerStub)
  end
end
