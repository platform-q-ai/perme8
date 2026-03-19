defmodule Agents.Pipeline.Domain.Entities.PipelineConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Step, DeployTarget}

  defp sample_stages do
    [
      Stage.new(%{
        name: "warm-pool",
        trigger: %{events: ["schedule", "on_demand"]},
        pool: %{target_count: 2, image: "opencode"}
      }),
      Stage.new(%{
        name: "build",
        trigger: %{events: ["on_session_complete"]},
        steps: [Step.new(%{name: "compile", command: "mix compile"})]
      }),
      Stage.new(%{
        name: "test",
        trigger: %{events: ["on_session_complete"]},
        steps: [Step.new(%{name: "test", command: "mix test"})]
      }),
      Stage.new(%{
        name: "deploy",
        trigger: %{events: ["on_merge"]},
        steps: [Step.new(%{name: "deploy", command: "render deploy"})]
      })
    ]
  end

  defp sample_deploy_targets do
    [
      DeployTarget.new(%{name: "render", type: "render", auto_deploy: true}),
      DeployTarget.new(%{name: "k3s", type: "k3s"})
    ]
  end

  defp sample_config(overrides \\ %{}) do
    defaults = %{
      version: 1,
      stages: sample_stages(),
      deploy_targets: sample_deploy_targets(),
      env: %{"MIX_ENV" => "test"},
      sessions: %{idle_timeout: 1800, terminate_on: ["merged", "closed"]},
      change_detection: %{"apps/agents/**" => "agents"}
    }

    PipelineConfig.new(Map.merge(defaults, overrides))
  end

  describe "new/1" do
    test "creates a PipelineConfig struct with all fields" do
      config = sample_config()

      assert %PipelineConfig{} = config
      assert config.version == 1
      assert length(config.stages) == 4
      assert length(config.deploy_targets) == 2
    end

    test "sets defaults" do
      config = PipelineConfig.new(%{})

      assert config.version == 1
      assert config.stages == []
      assert config.deploy_targets == []
      assert config.env == %{}
      assert config.toolchain == %{}
      assert config.services == %{}
      assert config.change_detection == %{}
      assert config.app_surface_map == %{}
      assert config.exo_bdd_matrix == %{}
      assert config.js_apps == %{}
      assert config.cache == %{}
      assert config.images == %{}
      assert config.sessions == %{}
      assert config.pull_requests == %{}
      assert config.merge_queue == %{}
    end
  end

  describe "stage_names/1" do
    test "returns list of stage names" do
      config = sample_config()

      assert PipelineConfig.stage_names(config) == ["warm-pool", "build", "test", "deploy"]
    end

    test "returns empty list for config with no stages" do
      config = PipelineConfig.new(%{})

      assert PipelineConfig.stage_names(config) == []
    end
  end

  describe "get_stage/2" do
    test "returns a stage by name" do
      config = sample_config()
      stage = PipelineConfig.get_stage(config, "build")

      assert %Stage{name: "build"} = stage
    end

    test "returns nil for unknown stage name" do
      config = sample_config()

      assert PipelineConfig.get_stage(config, "nonexistent") == nil
    end
  end

  describe "warm_pool_stage/1" do
    test "returns the warm-pool stage" do
      config = sample_config()
      stage = PipelineConfig.warm_pool_stage(config)

      assert %Stage{name: "warm-pool"} = stage
      assert stage.pool == %{target_count: 2, image: "opencode"}
    end

    test "returns nil when no warm-pool stage exists" do
      config = PipelineConfig.new(%{stages: [Stage.new(%{name: "build"})]})

      assert PipelineConfig.warm_pool_stage(config) == nil
    end
  end

  describe "deploy_target_names/1" do
    test "returns list of deploy target names" do
      config = sample_config()

      assert PipelineConfig.deploy_target_names(config) == ["render", "k3s"]
    end
  end

  describe "session_config/1" do
    test "returns the sessions map" do
      config = sample_config()

      assert PipelineConfig.session_config(config) == %{
               idle_timeout: 1800,
               terminate_on: ["merged", "closed"]
             }
    end
  end

  describe "environment_variables/1" do
    test "returns the env map" do
      config = sample_config()

      assert PipelineConfig.environment_variables(config) == %{"MIX_ENV" => "test"}
    end
  end

  describe "stage_count/1" do
    test "returns the number of stages" do
      config = sample_config()

      assert PipelineConfig.stage_count(config) == 4
    end
  end

  describe "ci_stages/1" do
    test "returns only stages triggered by CI events" do
      config = sample_config()
      ci = PipelineConfig.ci_stages(config)

      names = Enum.map(ci, & &1.name)
      assert "build" in names
      assert "test" in names
      assert "deploy" in names
      refute "warm-pool" in names
    end

    test "returns empty list when no CI stages exist" do
      config =
        PipelineConfig.new(%{
          stages: [
            Stage.new(%{name: "warm-pool", trigger: %{events: ["schedule"]}})
          ]
        })

      assert PipelineConfig.ci_stages(config) == []
    end
  end
end
