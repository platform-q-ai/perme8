defmodule Agents.Pipeline.Domain.Entities.StageTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Stage, Step, Gate}

  describe "new/1" do
    test "creates a Stage struct with all fields" do
      stage = Stage.new(%{name: "build", description: "Build the project"})

      assert %Stage{} = stage
      assert stage.name == "build"
      assert stage.description == "Build the project"
    end

    test "sets defaults" do
      stage = Stage.new(%{name: "test"})

      assert stage.steps == []
      assert stage.gate == nil
      assert stage.pool == nil
      assert stage.trigger == %{}
      assert stage.failure_action == "block"
      assert stage.timeout == nil
    end

    test "accepts all fields" do
      step = Step.new(%{name: "compile", command: "mix compile"})
      gate = Gate.new(%{requires: ["build"]})

      stage =
        Stage.new(%{
          name: "test",
          description: "Run tests",
          trigger: %{events: ["on_session_complete"]},
          steps: [step],
          gate: gate,
          pool: %{target_count: 2, image: "opencode"},
          failure_action: "reopen_session",
          timeout: 600
        })

      assert stage.name == "test"
      assert stage.trigger == %{events: ["on_session_complete"]}
      assert length(stage.steps) == 1
      assert stage.gate == gate
      assert stage.pool == %{target_count: 2, image: "opencode"}
      assert stage.failure_action == "reopen_session"
      assert stage.timeout == 600
    end
  end

  describe "warm_pool_stage?/1" do
    test "returns true for warm-pool stage" do
      stage = Stage.new(%{name: "warm-pool"})

      assert Stage.warm_pool_stage?(stage) == true
    end

    test "returns false for other stages" do
      stage = Stage.new(%{name: "build"})

      assert Stage.warm_pool_stage?(stage) == false
    end
  end

  describe "triggered_by?/1" do
    test "returns true when stage has matching trigger event" do
      stage = Stage.new(%{name: "test", trigger: %{events: ["on_session_complete", "manual"]}})

      assert Stage.triggered_by?(stage, "on_session_complete") == true
    end

    test "returns false when stage does not have matching trigger event" do
      stage = Stage.new(%{name: "test", trigger: %{events: ["on_session_complete"]}})

      assert Stage.triggered_by?(stage, "on_merge") == false
    end

    test "returns false when trigger has no events" do
      stage = Stage.new(%{name: "test", trigger: %{}})

      assert Stage.triggered_by?(stage, "on_session_complete") == false
    end

    test "returns false when trigger is empty map" do
      stage = Stage.new(%{name: "test"})

      assert Stage.triggered_by?(stage, "on_session_complete") == false
    end
  end

  describe "has_gate?/1" do
    test "returns true when gate is non-nil and non-empty" do
      gate = Gate.new(%{requires: ["build"]})
      stage = Stage.new(%{name: "test", gate: gate})

      assert Stage.has_gate?(stage) == true
    end

    test "returns false when gate is nil" do
      stage = Stage.new(%{name: "test"})

      assert Stage.has_gate?(stage) == false
    end

    test "returns false when gate is empty" do
      gate = Gate.new(%{})
      stage = Stage.new(%{name: "test", gate: gate})

      assert Stage.has_gate?(stage) == false
    end
  end

  describe "step_count/1" do
    test "returns the number of steps" do
      steps = [
        Step.new(%{name: "compile", command: "mix compile"}),
        Step.new(%{name: "test", command: "mix test"})
      ]

      stage = Stage.new(%{name: "build", steps: steps})

      assert Stage.step_count(stage) == 2
    end

    test "returns 0 for stage with no steps" do
      stage = Stage.new(%{name: "empty"})

      assert Stage.step_count(stage) == 0
    end
  end
end
