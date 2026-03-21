defmodule Agents.Pipeline.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Pipeline.Application, Agents.Repo],
    exports: [
      GitCommandRunner,
      GitDiffComputer,
      GitMerger,
      Repositories.PullRequestRepository,
      Schemas.PullRequestSchema,
      Schemas.ReviewCommentSchema,
      Schemas.ReviewSchema,
      YamlParser
    ]
end
