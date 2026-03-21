defmodule Agents.Pipeline.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain],
    exports: [
      Behaviours.PullRequestRepositoryBehaviour,
      Behaviours.GitDiffComputerBehaviour,
      Behaviours.GitMergerBehaviour,
      Behaviours.PipelineParserBehaviour,
      PipelineRuntimeConfig,
      UseCases.CommentOnPullRequest,
      UseCases.ClosePullRequest,
      UseCases.CreatePullRequest,
      UseCases.GetPullRequest,
      UseCases.GetPullRequestDiff,
      UseCases.ListPullRequests,
      UseCases.LoadPipeline,
      UseCases.MergePullRequest,
      UseCases.ReviewPullRequest,
      UseCases.UpdatePullRequest
    ]
end
