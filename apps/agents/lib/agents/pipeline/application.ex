defmodule Agents.Pipeline.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Sessions],
    exports: [
      Behaviours.PipelineRunRepositoryBehaviour,
      Behaviours.PullRequestRepositoryBehaviour,
      Behaviours.SessionReopenerBehaviour,
      Behaviours.StageExecutorBehaviour,
      Behaviours.GitDiffComputerBehaviour,
      Behaviours.GitMergerBehaviour,
      Behaviours.PipelineParserBehaviour,
      PipelineRuntimeConfig,
      UseCases.CommentOnPullRequest,
      UseCases.ClosePullRequest,
      UseCases.CreatePullRequest,
      UseCases.GetPipelineStatus,
      UseCases.GetPullRequest,
      UseCases.GetPullRequestDiff,
      UseCases.ListPullRequests,
      UseCases.LoadPipeline,
      UseCases.MergePullRequest,
      UseCases.RunStage,
      UseCases.ReviewPullRequest,
      UseCases.TriggerPipelineRun,
      UseCases.UpdatePullRequest
    ]
end
