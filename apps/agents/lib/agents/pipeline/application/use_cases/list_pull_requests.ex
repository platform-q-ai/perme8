defmodule Agents.Pipeline.Application.UseCases.ListPullRequests do
  @moduledoc "Lists internal pull requests with optional filters."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(keyword(), keyword()) :: {:ok, [PullRequest.t()]}
  def execute(filters \\ [], opts \\ []) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    prs =
      filters
      |> repo_module.list_filtered()
      |> Enum.map(&PullRequest.from_schema/1)

    {:ok, prs}
  end
end
