defmodule Agents.Pipeline.Application.UseCases.LoadPipelineTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @valid_yaml """
  version: 1
  env:
    MIX_ENV: test
  sessions:
    idle_timeout: 1800
  stages:
    - name: warm-pool
      description: Pre-provision containers
      trigger:
        events:
          - schedule
      pool:
        target_count: 2
        image: opencode
      steps:
        - name: provision
          type: provision_container
        - name: mark-ready
          type: mark_container_ready
    - name: build
      description: Compile
      trigger:
        events:
          - on_session_complete
      steps:
        - name: compile
          command: mix compile
    - name: test
      trigger:
        events:
          - on_session_complete
      gate:
        requires:
          - build
      steps:
        - name: run-tests
          command: mix test
  deploy:
    targets:
      - name: production
        type: render
        auto_deploy: true
  """

  describe "execute/1 — success path" do
    test "returns {:ok, PipelineConfig} with valid YAML string" do
      assert {:ok, %PipelineConfig{}} = LoadPipeline.execute(source: :string, input: @valid_yaml)
    end

    test "returned config passes validation" do
      {:ok, config} = LoadPipeline.execute(source: :string, input: @valid_yaml)

      assert config.version == 1
      assert length(config.stages) == 3
    end

    test "config stages are queryable by name" do
      {:ok, config} = LoadPipeline.execute(source: :string, input: @valid_yaml)

      build = PipelineConfig.get_stage(config, "build")
      assert build.name == "build"
    end

    test "warm-pool stage has pool settings" do
      {:ok, config} = LoadPipeline.execute(source: :string, input: @valid_yaml)

      warm = PipelineConfig.warm_pool_stage(config)
      assert warm != nil
      assert warm.pool["target_count"] == 2
    end

    test "deploy targets are populated" do
      {:ok, config} = LoadPipeline.execute(source: :string, input: @valid_yaml)

      assert PipelineConfig.deploy_target_names(config) == ["production"]
    end
  end

  describe "execute/1 — file source" do
    test "reads from file with injectable file reader" do
      reader = fn _path -> {:ok, @valid_yaml} end

      assert {:ok, %PipelineConfig{}} =
               LoadPipeline.execute(source: :file, path: "pipeline.yml", file_reader: reader)
    end

    test "returns error when file not found" do
      reader = fn _path -> {:error, :enoent} end

      assert {:error, :file_not_found} =
               LoadPipeline.execute(source: :file, path: "missing.yml", file_reader: reader)
    end
  end

  describe "execute/1 — parse failure" do
    test "returns error for invalid YAML" do
      bad_yaml = "{\ninvalid: [\nyaml: broken"

      assert {:error, :invalid_yaml} = LoadPipeline.execute(source: :string, input: bad_yaml)
    end
  end

  describe "execute/1 — validation failure" do
    test "returns error when version is missing" do
      yaml = """
      stages:
        - name: build
          steps:
            - name: s1
              command: echo
      """

      assert {:error, :missing_version} = LoadPipeline.execute(source: :string, input: yaml)
    end

    test "returns error when stage names duplicate" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            - name: s1
              command: echo
        - name: build
          steps:
            - name: s2
              command: echo
      """

      assert {:error, {:duplicate_stage_names, ["build"]}} =
               LoadPipeline.execute(source: :string, input: yaml)
    end

    test "returns error for invalid trigger event" do
      yaml = """
      version: 1
      stages:
        - name: build
          trigger:
            events:
              - on_unicorn
          steps:
            - name: s1
              command: echo
      """

      assert {:error, {:invalid_trigger_event, "build", "on_unicorn"}} =
               LoadPipeline.execute(source: :string, input: yaml)
    end
  end

  describe "execute/1 — default behaviour" do
    test "defaults to file source when no source specified" do
      reader = fn _path -> {:ok, @valid_yaml} end

      assert {:ok, %PipelineConfig{}} = LoadPipeline.execute(file_reader: reader)
    end
  end
end
