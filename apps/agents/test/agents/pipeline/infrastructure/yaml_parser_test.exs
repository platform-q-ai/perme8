defmodule Agents.Pipeline.Infrastructure.YamlParserTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.YamlParser
  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Step, Gate, DeployTarget}

  @valid_yaml """
  version: 1
  env:
    MIX_ENV: test
    DATABASE_URL: "postgres://localhost/perme8_test"
  toolchain:
    elixir: "1.19"
    erlang: "27"
  services:
    postgres:
      image: postgres:16
  change_detection:
    "apps/agents/**":
      app: agents
  sessions:
    idle_timeout: 1800
    terminate_on:
      - merged
      - closed
  stages:
    - name: warm-pool
      description: Pre-provision containers
      trigger:
        events:
          - schedule
          - on_demand
        schedule: "*/5 * * * *"
      pool:
        target_count: 2
        image: opencode
      steps:
        - name: provision-container
          type: provision_container
        - name: clone-repo
          command: "git clone $REPO_URL /workspace"
        - name: install-deps
          commands:
            - mix deps.get
            - mix deps.compile
        - name: mark-ready
          type: mark_container_ready
    - name: build
      description: Compile the project
      trigger:
        events:
          - on_session_complete
      steps:
        - name: compile
          command: mix compile --warnings-as-errors
    - name: test
      description: Run test suite
      trigger:
        events:
          - on_session_complete
      gate:
        requires:
          - build
        evaluation: all_of
      steps:
        - name: run-tests
          command: mix test
          env:
            MIX_ENV: test
    - name: deploy
      description: Deploy to production
      trigger:
        events:
          - on_merge
      gate:
        requires:
          - build
          - test
        evaluation: all_of
      steps:
        - name: deploy-render
          command: render deploy
  deploy:
    targets:
      - name: production
        type: render
        auto_deploy: true
        config:
          service_id: srv-123
      - name: staging
        type: k3s
  merge_queue:
    strategy: optimistic
    required_stages:
      - build
      - test
  """

  describe "parse/1 — successful parsing" do
    test "returns {:ok, PipelineConfig} for valid YAML" do
      assert {:ok, %PipelineConfig{}} = YamlParser.parse(@valid_yaml)
    end

    test "parsed config has correct version" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert config.version == 1
    end

    test "parses stages as Stage structs" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert length(config.stages) == 4
      assert Enum.all?(config.stages, &match?(%Stage{}, &1))
    end

    test "parses steps as Step structs within stages" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      warm_pool = Enum.find(config.stages, &(&1.name == "warm-pool"))

      assert length(warm_pool.steps) == 4
      assert Enum.all?(warm_pool.steps, &match?(%Step{}, &1))
    end

    test "parses step with single command" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      build = Enum.find(config.stages, &(&1.name == "build"))
      step = hd(build.steps)

      assert step.name == "compile"
      assert step.command == "mix compile --warnings-as-errors"
    end

    test "parses step with commands list" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      warm_pool = Enum.find(config.stages, &(&1.name == "warm-pool"))
      deps_step = Enum.find(warm_pool.steps, &(&1.name == "install-deps"))

      assert deps_step.commands == ["mix deps.get", "mix deps.compile"]
    end

    test "parses step with special type" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      warm_pool = Enum.find(config.stages, &(&1.name == "warm-pool"))
      provision = hd(warm_pool.steps)

      assert provision.name == "provision-container"
      assert provision.type == "provision_container"
    end

    test "parses stage gates as Gate structs" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      test_stage = Enum.find(config.stages, &(&1.name == "test"))

      assert %Gate{} = test_stage.gate
      assert test_stage.gate.requires == ["build"]
      assert test_stage.gate.evaluation == "all_of"
    end

    test "parses deploy targets as DeployTarget structs" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert length(config.deploy_targets) == 2
      assert Enum.all?(config.deploy_targets, &match?(%DeployTarget{}, &1))

      render = Enum.find(config.deploy_targets, &(&1.name == "production"))
      assert render.type == "render"
      assert render.auto_deploy == true
      assert render.config == %{"service_id" => "srv-123"}
    end

    test "parses warm-pool stage with pool settings" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      warm_pool = Enum.find(config.stages, &(&1.name == "warm-pool"))

      assert warm_pool.pool == %{"target_count" => 2, "image" => "opencode"}
    end

    test "parses environment variables" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert config.env == %{
               "MIX_ENV" => "test",
               "DATABASE_URL" => "postgres://localhost/perme8_test"
             }
    end

    test "parses change detection rules" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert config.change_detection == %{
               "apps/agents/**" => %{"app" => "agents"}
             }
    end

    test "parses session configuration" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert config.sessions == %{
               "idle_timeout" => 1800,
               "terminate_on" => ["merged", "closed"]
             }
    end

    test "preserves variable interpolation markers as strings" do
      yaml = """
      version: 1
      env:
        REPO_URL: "${GITHUB_REPO_URL}"
      stages:
        - name: build
          steps:
            - name: clone
              command: "git clone ${REPO_URL} /workspace"
      """

      {:ok, config} = YamlParser.parse(yaml)

      assert config.env["REPO_URL"] == "${GITHUB_REPO_URL}"
      step = hd(hd(config.stages).steps)
      assert step.command == "git clone ${REPO_URL} /workspace"
    end

    test "passes through toolchain, services, merge_queue as maps" do
      {:ok, config} = YamlParser.parse(@valid_yaml)

      assert config.toolchain == %{"elixir" => "1.19", "erlang" => "27"}
      assert config.services == %{"postgres" => %{"image" => "postgres:16"}}

      assert config.merge_queue == %{
               "strategy" => "optimistic",
               "required_stages" => ["build", "test"]
             }
    end

    test "parses step env as a map" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      test_stage = Enum.find(config.stages, &(&1.name == "test"))
      step = hd(test_stage.steps)

      assert step.env == %{"MIX_ENV" => "test"}
    end

    test "parses stage trigger with events and schedule" do
      {:ok, config} = YamlParser.parse(@valid_yaml)
      warm_pool = Enum.find(config.stages, &(&1.name == "warm-pool"))

      assert warm_pool.trigger == %{
               "events" => ["schedule", "on_demand"],
               "schedule" => "*/5 * * * *"
             }
    end
  end

  describe "parse/1 — edge cases" do
    test "handles stages with no steps" do
      yaml = """
      version: 1
      stages:
        - name: placeholder
          description: Empty stage
      """

      assert {:ok, config} = YamlParser.parse(yaml)
      stage = hd(config.stages)
      assert stage.name == "placeholder"
      assert stage.steps == []
    end

    test "handles stages with no trigger" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            - name: compile
              command: mix compile
      """

      assert {:ok, config} = YamlParser.parse(yaml)
      stage = hd(config.stages)
      assert stage.trigger == %{}
    end

    test "handles missing deploy section" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            - name: compile
              command: mix compile
      """

      assert {:ok, config} = YamlParser.parse(yaml)
      assert config.deploy_targets == []
    end

    test "handles missing env section" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            - name: compile
              command: mix compile
      """

      assert {:ok, config} = YamlParser.parse(yaml)
      assert config.env == %{}
    end

    test "handles stage with no gate" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            - name: compile
              command: mix compile
      """

      {:ok, config} = YamlParser.parse(yaml)
      assert hd(config.stages).gate == nil
    end
  end

  describe "parse/1 — error handling" do
    test "returns error for malformed YAML" do
      yaml = """
      version: 1
      stages:
        - name: build
          steps:
            bad indent: here
              nested: wrong
      """

      assert {:error, :invalid_yaml} = YamlParser.parse(yaml)
    end

    test "returns error when root is not a map" do
      yaml = "- item1\n- item2"

      assert {:error, :not_a_map} = YamlParser.parse(yaml)
    end

    test "returns error when version is absent" do
      yaml = """
      stages:
        - name: build
      """

      assert {:error, :missing_version} = YamlParser.parse(yaml)
    end

    test "returns error when stages key is absent" do
      yaml = """
      version: 1
      """

      assert {:error, :missing_stages} = YamlParser.parse(yaml)
    end

    test "returns error when stages is empty list" do
      yaml = """
      version: 1
      stages: []
      """

      assert {:error, :missing_stages} = YamlParser.parse(yaml)
    end
  end

  describe "parse_file/2" do
    test "reads a file and parses its content" do
      file_reader = fn _path -> {:ok, @valid_yaml} end

      assert {:ok, %PipelineConfig{}} =
               YamlParser.parse_file("perme8-pipeline.yml", file_reader: file_reader)
    end

    test "returns error for missing file" do
      file_reader = fn _path -> {:error, :enoent} end

      assert {:error, :file_not_found} =
               YamlParser.parse_file("missing.yml", file_reader: file_reader)
    end

    test "uses File.read as default reader" do
      # Attempt to read a nonexistent file — should return file_not_found
      assert {:error, :file_not_found} =
               YamlParser.parse_file(
                 "/tmp/nonexistent-perme8-pipeline-#{System.unique_integer()}.yml"
               )
    end
  end
end
