defmodule Agents.Pipeline.Domain.Entities.TransitionTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Transition

  test "new/1 builds an outcome transition" do
    transition = Transition.new(%{on: "failed", to_stage: "develop", reason: "checks_failed"})

    assert transition.on == "failed"
    assert transition.to_stage == "develop"
    assert transition.reason == "checks_failed"
  end
end
