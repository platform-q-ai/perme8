defmodule Agents.Pipeline.Infrastructure.GitMerger do
  @moduledoc "Executes git merge operations behind an injectable abstraction."

  @behaviour Agents.Pipeline.Application.Behaviours.GitMergerBehaviour

  alias Agents.Pipeline.Infrastructure.GitCommandRunner

  @impl true
  @spec merge(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def merge(source_branch, target_branch, method, opts \\ [])
      when is_binary(source_branch) and is_binary(target_branch) and is_binary(method) do
    runner = Keyword.get(opts, :command_runner, GitCommandRunner)
    remote = Keyword.get(opts, :remote, "origin")

    merge_command =
      case method do
        "merge" -> ["git", "merge", "--no-ff", source_branch]
        "squash" -> ["git", "merge", "--squash", source_branch]
        _ -> ["git", "merge", "--no-ff", source_branch]
      end

    with :ok <-
           run_command(runner, ["git", "checkout", target_branch], opts, :git_checkout_failed),
         :ok <- run_command(runner, merge_command, opts, :git_merge_failed),
         :ok <-
           run_command(runner, ["git", "push", remote, target_branch], opts, :git_push_failed) do
      :ok
    end
  end

  defp run_command(runner, command, opts, error_tag) do
    case runner.run(command, opts) do
      {0, _stdout, _stderr} -> :ok
      {_code, _stdout, stderr} -> {:error, {error_tag, stderr}}
    end
  end
end
