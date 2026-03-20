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
            steps:
              - name: prebuild image
                run: mix release
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
      assert Enum.any?(config.stages, &(&1.id == "warm-pool"))
      assert Enum.map(config.deploy_targets, & &1.id) == ["dev", "prod"]
    end

    test "returns actionable errors for invalid config" do
      yaml = """
      version: 1
      pipeline:
        name: bad-pipeline
        stages:
          - id: warm-pool
            type: warm_pool
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
  end
end
