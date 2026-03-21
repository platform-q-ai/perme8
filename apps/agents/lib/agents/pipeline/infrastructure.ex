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
      PipelineEventHandler,
      PipelineScheduler,
      Repositories.PipelineRunRepository,
      Repositories.PullRequestRepository,
      SessionReopener,
      StageExecutor,
      TaskContextProvider,
      WarmPoolCounter,
      Schemas.PipelineRunSchema,
      Schemas.PullRequestSchema,
      Schemas.ReviewCommentSchema,
      Schemas.ReviewSchema,
      YamlParser
    ]
end
