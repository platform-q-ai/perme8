defmodule Agents.Pipeline.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Events.PipelineStageChanged,
      Events.PullRequestCreated,
      Events.PullRequestMerged,
      Events.PullRequestUpdated,
      Entities.Gate,
      Entities.PipelineConfig,
      Entities.PipelineRun,
      Entities.PullRequest,
      Entities.Review,
      Entities.ReviewComment,
      Entities.StageResult,
      Entities.Stage,
      Entities.Step,
      Policies.MergeQueuePolicy,
      Policies.WarmPoolPolicy,
      Policies.PipelineLifecyclePolicy,
      Policies.PullRequestPolicy
    ]
end
