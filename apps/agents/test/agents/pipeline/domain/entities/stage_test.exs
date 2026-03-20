defmodule Agents.Pipeline.Domain.Entities.StageTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Gate, Stage, Step}

  test "new/1 keeps nested steps and gates" do
    stage =
      Stage.new(%{
        id: "warm-pool",
        type: "warm_pool",
        steps: [Step.new(%{name: "boot", run: "./boot.sh"})],
        gates: [Gate.new(%{type: "health-check"})]
      })

    assert stage.id == "warm-pool"
    assert [%Step{name: "boot"}] = stage.steps
    assert [%Gate{type: "health-check"}] = stage.gates
  end
end
