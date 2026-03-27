defmodule Agents.Pipeline.Domain.Entities.PipelineConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Gate, PipelineConfig, Stage, Step}

  test "new/1 builds a full pipeline config with nested value objects" do
    step = Step.new(%{name: "compile", run: "mix compile"})
    gate = Gate.new(%{type: "quality", required: true, params: %{checks: ["unit"]}})

    stage =
      Stage.new(%{
        id: "warm-pool",
        type: "warm_pool",
        triggers: ["on_ticket_play"],
        ticket_concurrency: 1,
        steps: [step],
        gates: [gate]
      })

    config =
      PipelineConfig.new(%{
        version: 1,
        name: "perme8-core",
        stages: [stage]
      })

    assert config.version == 1
    assert config.name == "perme8-core"
    assert [%Stage{id: "warm-pool"}] = config.stages
    assert hd(config.stages).ticket_concurrency == 1
  end
end
