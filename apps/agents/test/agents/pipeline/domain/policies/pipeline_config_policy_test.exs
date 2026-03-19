defmodule Agents.Pipeline.Domain.Policies.PipelineConfigPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Policies.PipelineConfigPolicy
  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Step, Gate, DeployTarget}

  defp valid_config(overrides \\ %{}) do
    defaults = %{
      version: 1,
      stages: [
        Stage.new(%{
          name: "build",
          trigger: %{events: ["on_session_complete"]},
          steps: [Step.new(%{name: "compile", command: "mix compile"})]
        }),
        Stage.new(%{
          name: "test",
          trigger: %{events: ["on_session_complete"]},
          gate: Gate.new(%{requires: ["build"]}),
          steps: [Step.new(%{name: "run-tests", command: "mix test"})]
        })
      ],
      deploy_targets: [
        DeployTarget.new(%{name: "production", type: "render"})
      ]
    }

    PipelineConfig.new(Map.merge(defaults, overrides))
  end

  describe "validate/1 — version validation" do
    test "returns :ok for version 1" do
      config = valid_config()

      assert :ok = PipelineConfigPolicy.validate(config)
    end

    test "returns error when version is nil" do
      config = valid_config(%{version: nil})

      assert {:error, :missing_version} = PipelineConfigPolicy.validate(config)
    end

    test "returns error for unsupported version" do
      config = valid_config(%{version: 99})

      assert {:error, {:unsupported_version, 99}} = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — stage validation" do
    test "returns error when stages list is empty" do
      config = valid_config(%{stages: []})

      assert {:error, :no_stages} = PipelineConfigPolicy.validate(config)
    end

    test "returns error when stage names repeat" do
      stages = [
        Stage.new(%{name: "build", steps: [Step.new(%{name: "s1", command: "echo"})]}),
        Stage.new(%{name: "build", steps: [Step.new(%{name: "s2", command: "echo"})]})
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:duplicate_stage_names, ["build"]}} =
               PipelineConfigPolicy.validate(config)
    end

    test "returns error when any stage has nil name" do
      stages = [
        Stage.new(%{name: nil, steps: [Step.new(%{name: "s1", command: "echo"})]}),
        Stage.new(%{name: "build", steps: [Step.new(%{name: "s2", command: "echo"})]})
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:stages_missing_names, [0]}} = PipelineConfigPolicy.validate(config)
    end

    test "returns error when any stage has empty string name" do
      stages = [
        Stage.new(%{name: "", steps: [Step.new(%{name: "s1", command: "echo"})]}),
        Stage.new(%{name: "build", steps: [Step.new(%{name: "s2", command: "echo"})]})
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:stages_missing_names, [0]}} = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — trigger validation" do
    test "returns error for unrecognized trigger event" do
      stages = [
        Stage.new(%{
          name: "build",
          trigger: %{events: ["on_unicorn"]},
          steps: [Step.new(%{name: "s1", command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:invalid_trigger_event, "build", "on_unicorn"}} =
               PipelineConfigPolicy.validate(config)
    end

    test "accepts all valid trigger events" do
      valid_events = [
        "on_session_complete",
        "on_pull_request",
        "on_merge",
        "schedule",
        "on_demand",
        "manual"
      ]

      for event <- valid_events do
        stages = [
          Stage.new(%{
            name: "stage-#{event}",
            trigger: %{events: [event]},
            steps: [Step.new(%{name: "s1", command: "echo"})]
          })
        ]

        config = valid_config(%{stages: stages})
        assert :ok = PipelineConfigPolicy.validate(config), "Expected #{event} to be valid"
      end
    end

    test "accepts stage with no trigger (empty map)" do
      stages = [
        Stage.new(%{
          name: "build",
          trigger: %{},
          steps: [Step.new(%{name: "s1", command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})

      assert :ok = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — step validation" do
    test "returns error when a step has no name" do
      stages = [
        Stage.new(%{
          name: "build",
          steps: [Step.new(%{name: nil, command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:step_missing_name, "build", 0}} =
               PipelineConfigPolicy.validate(config)
    end

    test "accepts steps with a name and command" do
      stages = [
        Stage.new(%{
          name: "build",
          steps: [Step.new(%{name: "compile", command: "mix compile"})]
        })
      ]

      config = valid_config(%{stages: stages})
      assert :ok = PipelineConfigPolicy.validate(config)
    end

    test "accepts steps with a name and special type" do
      stages = [
        Stage.new(%{
          name: "warm-pool",
          steps: [Step.new(%{name: "provision", type: "provision_container"})]
        })
      ]

      config = valid_config(%{stages: stages})
      assert :ok = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — gate validation" do
    test "returns error for unknown evaluation strategy" do
      stages = [
        Stage.new(%{
          name: "build",
          gate: Gate.new(%{requires: [], evaluation: "none_of"}),
          steps: [Step.new(%{name: "s1", command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:invalid_gate_evaluation, "build", "none_of"}} =
               PipelineConfigPolicy.validate(config)
    end

    test "returns error when gate references unknown stage" do
      stages = [
        Stage.new(%{
          name: "test",
          gate: Gate.new(%{requires: ["nonexistent"]}),
          steps: [Step.new(%{name: "s1", command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})

      assert {:error, {:gate_references_unknown_stage, "test", "nonexistent"}} =
               PipelineConfigPolicy.validate(config)
    end

    test "accepts gate with valid evaluation and existing dependencies" do
      stages = [
        Stage.new(%{
          name: "build",
          steps: [Step.new(%{name: "s1", command: "echo"})]
        }),
        Stage.new(%{
          name: "test",
          gate: Gate.new(%{requires: ["build"], evaluation: "all_of"}),
          steps: [Step.new(%{name: "s2", command: "echo"})]
        })
      ]

      config = valid_config(%{stages: stages})
      assert :ok = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — deploy target validation" do
    test "returns error for unrecognized deploy target type" do
      targets = [DeployTarget.new(%{name: "prod", type: "heroku"})]

      config = valid_config(%{deploy_targets: targets})

      assert {:error, {:invalid_deploy_target_type, "prod", "heroku"}} =
               PipelineConfigPolicy.validate(config)
    end

    test "accepts render and k3s types" do
      targets = [
        DeployTarget.new(%{name: "prod", type: "render"}),
        DeployTarget.new(%{name: "staging", type: "k3s"})
      ]

      config = valid_config(%{deploy_targets: targets})
      assert :ok = PipelineConfigPolicy.validate(config)
    end

    test "accepts empty deploy targets list" do
      config = valid_config(%{deploy_targets: []})
      assert :ok = PipelineConfigPolicy.validate(config)
    end
  end

  describe "validate/1 — composite validation" do
    test "returns :ok for a fully valid PipelineConfig" do
      config = valid_config()

      assert :ok = PipelineConfigPolicy.validate(config)
    end

    test "fails fast — returns first error encountered" do
      config = valid_config(%{version: nil, stages: []})

      assert {:error, :missing_version} = PipelineConfigPolicy.validate(config)
    end
  end

  describe "valid_trigger_events/0" do
    test "returns the full list of valid events" do
      events = PipelineConfigPolicy.valid_trigger_events()

      assert "on_session_complete" in events
      assert "on_pull_request" in events
      assert "on_merge" in events
      assert "schedule" in events
      assert "on_demand" in events
      assert "manual" in events
    end
  end

  describe "valid_stage_name?/1" do
    test "returns true for a valid name" do
      assert PipelineConfigPolicy.valid_stage_name?("build") == true
    end

    test "returns false for nil" do
      assert PipelineConfigPolicy.valid_stage_name?(nil) == false
    end

    test "returns false for empty string" do
      assert PipelineConfigPolicy.valid_stage_name?("") == false
    end

    test "returns false for non-string" do
      assert PipelineConfigPolicy.valid_stage_name?(123) == false
    end
  end
end
