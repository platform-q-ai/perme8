defmodule Agents.Pipeline.Application.UseCases.MergePullRequest do
  @moduledoc "Merges an approved internal pull request through an infrastructure adapter."

  alias Agents.Pipeline.Domain.Entities.PullRequest
  alias Agents.Pipeline.Infrastructure.GitMerger
  alias Agents.Pipeline.Infrastructure.Repositories.PullRequestRepository

  @spec execute(integer(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, opts \\ []) when is_integer(number) do
    repo_module = Keyword.get(opts, :pull_request_repo, PullRequestRepository)
    git_merger = Keyword.get(opts, :git_merger, GitMerger)
    merge_method = Keyword.get(opts, :merge_method, "merge")

    with {:ok, pr} <- repo_module.get_by_number(number),
         :ok <- ensure_mergeable(pr.status),
         :ok <- git_merger.merge(pr.source_branch, pr.target_branch, merge_method),
         {:ok, merged} <-
           repo_module.update_pull_request(number, %{
             status: "merged",
             merged_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }) do
      {:ok, PullRequest.from_schema(merged)}
    end
  end

  defp ensure_mergeable("approved"), do: :ok
  defp ensure_mergeable(_), do: {:error, :not_mergeable}
end
