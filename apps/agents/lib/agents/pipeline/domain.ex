defmodule Agents.Pipeline.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.DeployTarget,
      Entities.Gate,
      Entities.PipelineConfig,
      Entities.PullRequest,
      Entities.Review,
      Entities.ReviewComment,
      Entities.Stage,
      Entities.Step,
      Policies.PullRequestPolicy
    ]
end
