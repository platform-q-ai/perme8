defmodule Agents.Pipeline.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.PipelineConfig,
      Entities.Stage,
      Entities.Step,
      Entities.Gate,
      Entities.DeployTarget,
      Policies.PipelineConfigPolicy
    ]
end
