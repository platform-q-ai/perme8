defmodule Agents.Pipeline.Infrastructure.GitMergerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.GitMerger

  defmodule CommandRunnerStub do
    def run(command, opts) do
      Process.get({__MODULE__, :run}).(command, opts)
    end
  end

  test "runs git merge command for merge method" do
    Process.put({CommandRunnerStub, :run}, fn command, _opts ->
      assert command == ["git", "merge", "--no-ff", "feature/x"]
      {0, "", ""}
    end)

    assert :ok = GitMerger.merge("feature/x", "main", "merge", command_runner: CommandRunnerStub)
  end

  test "returns error when merge command fails" do
    Process.put({CommandRunnerStub, :run}, fn _command, _opts ->
      {1, "", "conflict"}
    end)

    assert {:error, {:git_merge_failed, "conflict"}} =
             GitMerger.merge("feature/x", "main", "merge", command_runner: CommandRunnerStub)
  end
end
