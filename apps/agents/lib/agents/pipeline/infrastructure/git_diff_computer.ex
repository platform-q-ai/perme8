defmodule Agents.Pipeline.Infrastructure.GitDiffComputer do
  @moduledoc "Computes git diffs for internal pull requests."

  @behaviour Agents.Pipeline.Application.Behaviours.GitDiffComputerBehaviour

  alias Agents.Pipeline.Infrastructure.GitCommandRunner

  @impl true
  @spec compute_diff(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def compute_diff(source_branch, target_branch) do
    compute_diff(source_branch, target_branch, [])
  end

  @spec compute_diff(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def compute_diff(source_branch, target_branch, opts)
      when is_binary(source_branch) and is_binary(target_branch) do
    runner = Keyword.get(opts, :command_runner, GitCommandRunner)
    cmd = ["git", "diff", "#{target_branch}...#{source_branch}"]

    case runner.run(cmd, opts) do
      {0, stdout, _stderr} -> {:ok, stdout}
      {_code, _stdout, stderr} -> {:error, {:git_diff_failed, stderr}}
    end
  end
end
