defmodule Agents.Pipeline.Infrastructure.YamlParserTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.YamlParser

  describe "parse_string/1" do
    test "parses a valid pipeline config with warm-pool stage" do
      yaml = """
      version: 1
      pipeline:
        name: perme8-core
        description: Core agent execution pipeline
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
            strategy: rolling
          - id: prod
            environment: production
            provider: kubernetes
            strategy: canary
            region: us-east-1
        stages:
          - id: warm-pool
            type: warm_pool
            deploy_target: dev
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
                required_step: prestart containers
            steps:
              - name: prebuild image
                run: mix release
                conditions: branch == main
              - name: prestart containers
                run: scripts/warm_pool.sh
            gates:
              - type: quality
                required: true
                checks:
                  - smoke
          - id: deploy
            type: deploy
            deploy_target: prod
            steps:
              - name: deploy app
                run: scripts/deploy.sh
      """

      assert {:ok, config} = YamlParser.parse_string(yaml)
      assert config.version == 1
      assert config.name == "perme8-core"
      assert config.description == "Core agent execution pipeline"
      assert Enum.any?(config.stages, &(&1.id == "warm-pool"))
      assert Enum.map(config.deploy_targets, & &1.id) == ["dev", "prod"]

      assert [%{strategy: "rolling"}, %{strategy: "canary", region: "us-east-1"}] =
               config.deploy_targets

      warm_pool = Enum.find(config.stages, &(&1.id == "warm-pool"))

      assert [
               %{timeout_seconds: nil, retries: 0, conditions: "branch == main"},
               %{timeout_seconds: nil, retries: 0, conditions: nil}
             ] =
               warm_pool.steps

      assert warm_pool.schedule == %{"cron" => "*/5 * * * *"}

      assert warm_pool.config == %{
               "warm_pool" => %{
                 "target_count" => 2,
                 "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
                 "readiness" => %{
                   "strategy" => "command_success",
                   "required_step" => "prestart containers"
                 }
               }
             }

      assert [%{type: "quality", required: true, params: %{"checks" => ["smoke"]}}] =
               warm_pool.gates
    end

    test "returns actionable errors for invalid config" do
      yaml = """
      version: 1
      pipeline:
        name: bad-pipeline
        stages:
          - id: warm-pool
            type: warm_pool
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
            steps: []
      """

      assert {:error, errors} = YamlParser.parse_string(yaml)
      assert "pipeline.deploy_targets must be a non-empty list" in errors
      assert "pipeline.stages[0].steps must be a non-empty list" in errors
    end

    test "requires a warm-pool stage" do
      yaml = """
      version: 1
      pipeline:
        name: missing-warm-pool
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
        stages:
          - id: build
            type: build
            steps:
              - name: compile
                run: mix compile
      """

      assert {:error, errors} = YamlParser.parse_string(yaml)
      assert "pipeline.stages must include a stage with id 'warm-pool'" in errors
    end

    test "preserves false gate requirements" do
      yaml = """
      version: 1
      pipeline:
        name: optional-gate
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
        stages:
          - id: warm-pool
            type: warm_pool
            deploy_target: dev
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
            gates:
              - type: manual_approval
                required: false
      """

      assert {:ok, config} = YamlParser.parse_string(yaml)
      [%{gates: [%{required: required}]}] = config.stages
      assert required == false
    end

    test "parses merge queue policy configuration" do
      yaml = """
      version: 1
      pipeline:
        name: merge-queue-enabled
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
        merge_queue:
          strategy: merge_queue
          required_stages:
            - test
            - boundary
          required_review: true
          pre_merge_validation:
            strategy: re_run_required_stages
            use_existing_container: true
        stages:
          - id: warm-pool
            type: warm_pool
            deploy_target: dev
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
          - id: test
            type: verification
            deploy_target: dev
            steps:
              - name: unit
                run: mix test
      """

      assert {:ok, config} = YamlParser.parse_string(yaml)
      assert config.merge_queue["strategy"] == "merge_queue"
      assert config.merge_queue["required_stages"] == ["test", "boundary"]
      assert config.merge_queue["required_review"] == true
      assert config.merge_queue["pre_merge_validation"]["strategy"] == "re_run_required_stages"
    end

    test "rejects invalid optional and referenced fields" do
      yaml = """
      version: 1
      pipeline:
        name: broken-details
        description:
          nested: nope
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
        stages:
          - id: warm-pool
            type: warm_pool
            deploy_target: prod
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: nope
              image: 123
              readiness: []
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
                env:
                  - invalid
      """

      assert {:error, errors} = YamlParser.parse_string(yaml)
      assert "pipeline.description must be a string when present" in errors

      assert "pipeline.stages[0].deploy_target must reference a declared deploy target" in errors

      assert "pipeline.stages[0].warm_pool.target_count must be a non-negative integer" in errors
      assert "pipeline.stages[0].warm_pool.image must be a string" in errors
      assert "pipeline.stages[0].warm_pool.readiness must be a map" in errors

      assert "pipeline.stages[0].steps[0].env must be a map" in errors
    end
  end

  describe "parse_file/1" do
    test "loads a pipeline document from disk" do
      path =
        write_tmp_file("""
        version: 1
        pipeline:
          name: perme8-core
          deploy_targets:
            - id: dev
              environment: development
              provider: docker
          stages:
            - id: warm-pool
              type: warm_pool
              deploy_target: dev
              schedule:
                cron: \"*/5 * * * *\"
              warm_pool:
                target_count: 2
                image: ghcr.io/platform-q-ai/perme8-runtime:latest
                readiness:
                  strategy: command_success
              steps:
                - name: prestart
                  run: scripts/warm_pool.sh
        """)

      assert {:ok, config} = YamlParser.parse_file(path)
      assert Enum.any?(config.stages, &(&1.id == "warm-pool"))
    end

    test "returns a file error when the path is unreadable" do
      assert {:error, [message]} = YamlParser.parse_file("/definitely/missing/pipeline.yml")
      assert message =~ "invalid YAML"
    end

    test "returns an invalid YAML error for malformed content" do
      path = write_tmp_file("version: [unterminated")

      assert {:error, [message]} = YamlParser.parse_file(path)
      assert message =~ "invalid YAML"
    end

    test "rejects YAML roots that are not maps" do
      path = write_tmp_file("- just\n- a\n- list\n")

      assert {:error, [message]} = YamlParser.parse_file(path)
      assert message =~ "invalid YAML root: expected map"
    end
  end

  defp write_tmp_file(content) do
    path =
      Path.join(System.tmp_dir!(), "pipeline-parser-#{System.unique_integer([:positive])}.yml")

    File.write!(path, content)
    path
  end
end
