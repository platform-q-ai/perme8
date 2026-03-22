defmodule Agents.Pipeline.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Sessions, Agents.Tickets.Domain],
    exports: [
      Behaviours.PipelineRunRepositoryBehaviour,
      Behaviours.PullRequestRepositoryBehaviour,
      Behaviours.SessionReopenerBehaviour,
      Behaviours.StageExecutorBehaviour,
      Behaviours.TaskContextProviderBehaviour,
      Behaviours.GitDiffComputerBehaviour,
      Behaviours.GitMergerBehaviour,
      Behaviours.PipelineParserBehaviour,
      PipelineRuntimeConfig,
      TicketFacingStageCatalog,
      UseCases.CommentOnPullRequest,
      UseCases.ClosePullRequest,
      UseCases.CreatePullRequest,
      UseCases.GetPipelineKanban,
      UseCases.GetPipelineStatus,
      UseCases.GetPullRequest,
      UseCases.GetPullRequestByLinkedTicket,
      UseCases.GetPullRequestDiff,
      UseCases.ListPullRequests,
      UseCases.LoadPipeline,
      UseCases.MergePullRequest,
      UseCases.ReplenishWarmPool,
      UseCases.ReplyToPullRequestComment,
      UseCases.ResolvePullRequestThread,
      UseCases.RunStage,
      UseCases.ReviewPullRequest,
      UseCases.TriggerPipelineRun,
      UseCases.UpdatePullRequest
    ]
end
