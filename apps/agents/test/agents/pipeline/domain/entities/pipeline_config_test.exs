defmodule Agents.Pipeline.Domain.Entities.PipelineConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{DeployTarget, Gate, PipelineConfig, Stage, Step}

  test "new/1 builds a full pipeline config with nested value objects" do
    step = Step.new(%{name: "compile", run: "mix compile"})
    gate = Gate.new(%{type: "quality", required: true, params: %{checks: ["unit"]}})

    stage =
      Stage.new(%{
        id: "warm-pool",
        type: "warm_pool",
        deploy_target: "dev",
        steps: [step],
        gates: [gate]
      })

    target =
      DeployTarget.new(%{
        id: "dev",
        environment: "development",
        provider: "docker",
        strategy: "rolling"
      })

    config =
      PipelineConfig.new(%{
        version: 1,
        name: "perme8-core",
        stages: [stage],
        deploy_targets: [target]
      })

    assert config.version == 1
    assert config.name == "perme8-core"
    assert [%Stage{id: "warm-pool"}] = config.stages
    assert [%DeployTarget{id: "dev"}] = config.deploy_targets
  end
end
