defmodule Agents.Pipeline.Application.UseCases.GetPullRequestDiff do
  @moduledoc "Computes git diff for an internal pull request."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), keyword()) ::
          {:ok, %{pull_request: PullRequest.t(), diff: String.t()}} | {:error, term()}
  def execute(number, opts \\ []) when is_integer(number) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    diff_computer = Keyword.get(opts, :diff_computer, PipelineRuntimeConfig.git_diff_computer())

    with {:ok, pr} <- repo_module.get_by_number(number),
         {:ok, diff} <- diff_computer.compute_diff(pr.source_branch, pr.target_branch) do
      {:ok, %{pull_request: PullRequest.from_schema(pr), diff: diff}}
    end
  end
end
