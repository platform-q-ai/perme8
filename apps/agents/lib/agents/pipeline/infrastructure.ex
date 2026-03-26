defmodule Agents.Pipeline.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Pipeline.Application, Agents.Repo, Agents.Sessions],
    exports: [
      ExoBddGitDiffComputer,
      ExoBddGitMerger,
      GateEvaluator,
      GitCommandRunner,
      GitDiffComputer,
      GitMerger,
      PipelineEventHandler,
      PipelineScheduler,
      Repositories.PipelineConfigRepository,
      Repositories.PipelineRunRepository,
      Repositories.PullRequestRepository,
      Schemas.PipelineConfigSchema,
      Schemas.PipelineGateSchema,
      Schemas.PipelineStageSchema,
      Schemas.PipelineStepSchema,
      Schemas.PipelineTransitionSchema,
      SessionReopener,
      StageExecutor,
      TaskContextProvider,
      Schemas.PipelineRunSchema,
      Schemas.PullRequestSchema,
      Schemas.ReviewCommentSchema,
      Schemas.ReviewSchema
    ]
end
