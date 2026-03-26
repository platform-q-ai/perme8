defmodule Agents.Pipeline.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Pipeline.Application, Agents.Repo, Agents.Sessions],
    exports: [
      ExoBddGitDiffComputer,
      ExoBddGitMerger,
      GitCommandRunner,
      GitDiffComputer,
      GitMerger,
      MergeQueueWorker,
      PipelineEventHandler,
      PipelineScheduler,
      Repositories.PipelineConfigRepository,
      Repositories.PipelineRunRepository,
      Repositories.PullRequestRepository,
      Schemas.PipelineConfigSchema,
      Schemas.PipelineDeployTargetSchema,
      Schemas.PipelineGateSchema,
      Schemas.PipelineStageSchema,
      Schemas.PipelineStepSchema,
      SessionReopener,
      StageExecutor,
      TaskContextProvider,
      WarmPoolCounter,
      Schemas.PipelineRunSchema,
      Schemas.PullRequestSchema,
      Schemas.ReviewCommentSchema,
      Schemas.ReviewSchema
    ]
end
