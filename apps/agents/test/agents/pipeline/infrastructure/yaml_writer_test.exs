defmodule Agents.Pipeline.Infrastructure.YamlWriterTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.YamlParser
  alias Agents.Pipeline.Infrastructure.YamlWriter

  describe "dump/1" do
    test "serializes normalized config in deterministic key order and reparses" do
      config = %{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "description" => "Core pipeline",
          "merge_queue" => %{
            "strategy" => "merge_queue",
            "required_stages" => ["test"],
            "required_review" => true,
            "pre_merge_validation" => %{"strategy" => "re_run_required_stages"}
          },
          "deploy_targets" => [
            %{
              "id" => "dev",
              "environment" => "development",
              "provider" => "docker",
              "strategy" => "rolling"
            }
          ],
          "stages" => [
            %{
              "id" => "warm-pool",
              "type" => "warm_pool",
              "deploy_target" => "dev",
              "schedule" => %{"cron" => "*/5 * * * *"},
              "warm_pool" => %{
                "target_count" => 2,
                "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
                "readiness" => %{"strategy" => "command_success"}
              },
              "steps" => [
                %{
                  "name" => "prebuild",
                  "run" => "mix release",
                  "timeout_seconds" => 900,
                  "retries" => 1,
                  "conditions" => "branch == main",
                  "env" => %{"MIX_ENV" => "test"}
                }
              ],
              "gates" => [%{"type" => "quality", "required" => true, "checks" => ["smoke"]}]
            }
          ]
        }
      }

      assert {:ok, yaml} = YamlWriter.dump(config)

      assert String.contains?(yaml, "version: 1\npipeline:")

      assert String.contains?(
               yaml,
               "  name: perme8-core\n  description: Core pipeline\n  merge_queue:\n"
             )

      assert String.contains?(yaml, "      conditions: \"branch == main\"")
      assert String.contains?(yaml, "          env:\n            MIX_ENV: test")

      assert {:ok, parsed} = YamlParser.parse_string(yaml)
      stage = Enum.find(parsed.stages, &(&1.id == "warm-pool"))
      assert [%{conditions: "branch == main"}] = stage.steps
    end

    test "serializes parsed pipeline config structs" do
      yaml = """
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
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
      """

      assert {:ok, config} = YamlParser.parse_string(yaml)
      assert {:ok, dumped} = YamlWriter.dump(config)
      assert {:ok, reparsed} = YamlParser.parse_string(dumped)

      assert reparsed.name == config.name
      assert Enum.map(reparsed.stages, & &1.id) == Enum.map(config.stages, & &1.id)
    end
  end
end
