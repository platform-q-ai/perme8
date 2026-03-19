defmodule Agents.Pipeline.Integration.LoadPipelineIntegrationTest do
  @moduledoc """
  Integration tests that load the actual perme8-pipeline.yml from the repo root.
  """
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Gate, DeployTarget}

  @pipeline_path Path.expand("../../../../../../perme8-pipeline.yml", __DIR__)

  describe "loading the real perme8-pipeline.yml" do
    test "parses successfully" do
      assert {:ok, %PipelineConfig{}} = LoadPipeline.execute(source: :file, path: @pipeline_path)
    end

    test "has version 1" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      assert config.version == 1
    end

    test "contains the expected stages" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      stage_names = PipelineConfig.stage_names(config)

      assert "warm-pool" in stage_names
      assert "changes" in stage_names
      assert "build" in stage_names
      assert "test" in stage_names
      assert "exo-bdd-360" in stage_names
      assert "selective-matrix" in stage_names
      assert "ci-gate" in stage_names
      assert "integration-test" in stage_names
      assert "deploy" in stage_names
    end

    test "warm-pool stage has pool settings" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      warm = PipelineConfig.warm_pool_stage(config)
      assert %Stage{} = warm
      assert warm.pool["target_count"] == 2
      assert warm.pool["image"] == "opencode"
    end

    test "warm-pool stage has provisioning steps" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      warm = PipelineConfig.warm_pool_stage(config)
      step_names = Enum.map(warm.steps, & &1.name)

      assert "provision-container" in step_names
      assert "clone-repo" in step_names
      assert "install-deps" in step_names
      assert "compile" in step_names
      assert "setup-database" in step_names
      assert "mark-ready" in step_names
    end

    test "deploy targets are populated" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      target_names = PipelineConfig.deploy_target_names(config)
      assert "production" in target_names
      assert "staging-k3s" in target_names
    end

    test "production deploy target is render type" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      prod = Enum.find(config.deploy_targets, &(&1.name == "production"))
      assert %DeployTarget{type: "render"} = prod
      assert DeployTarget.auto_deploy?(prod) == true
    end

    test "session configuration is present" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      sessions = PipelineConfig.session_config(config)
      assert sessions["idle_timeout"] == 1800
      assert sessions["terminate_on"] == ["merged", "closed"]
    end

    test "change detection rules map paths to app names" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      assert is_map(config.change_detection)
      assert config.change_detection["apps/agents/**"] == %{"app" => "agents"}
      assert config.change_detection["apps/identity/**"] == %{"app" => "identity"}
    end

    test "environment variable definitions are present" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      env = PipelineConfig.environment_variables(config)
      assert is_map(env)
      assert Map.has_key?(env, "MIX_ENV")
      assert Map.has_key?(env, "REPO_URL")
    end

    test "build stage has gate requiring changes" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      build = PipelineConfig.get_stage(config, "build")
      assert %Gate{} = build.gate
      assert "changes" in Gate.dependency_names(build.gate)
    end

    test "test stage has gate requiring build" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      test_stage = PipelineConfig.get_stage(config, "test")
      assert %Gate{} = test_stage.gate
      assert "build" in Gate.dependency_names(test_stage.gate)
    end

    test "ci-gate requires all CI stages" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      ci_gate = PipelineConfig.get_stage(config, "ci-gate")
      deps = Gate.dependency_names(ci_gate.gate)

      assert "build" in deps
      assert "test" in deps
      assert "exo-bdd-360" in deps
      assert "selective-matrix" in deps
    end

    test "stages have proper trigger events" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      build = PipelineConfig.get_stage(config, "build")
      assert Stage.triggered_by?(build, "on_session_complete")

      deploy = PipelineConfig.get_stage(config, "deploy")
      assert Stage.triggered_by?(deploy, "on_merge")
    end

    test "test stage has failure_action reopen_session" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      test_stage = PipelineConfig.get_stage(config, "test")
      assert test_stage.failure_action == "reopen_session"
    end

    test "merge queue configuration is present" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      assert config.merge_queue["strategy"] == "optimistic"
      assert is_list(config.merge_queue["required_stages"])
    end

    test "ci_stages returns only CI-triggered stages" do
      {:ok, config} = LoadPipeline.execute(source: :file, path: @pipeline_path)

      ci = PipelineConfig.ci_stages(config)
      ci_names = Enum.map(ci, & &1.name)

      assert "build" in ci_names
      assert "test" in ci_names
      assert "deploy" in ci_names
      refute "warm-pool" in ci_names
    end
  end
end
