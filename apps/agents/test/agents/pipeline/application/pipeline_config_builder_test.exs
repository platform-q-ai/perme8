defmodule Agents.Pipeline.Application.PipelineConfigBuilderTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.PipelineConfigBuilder

  test "builds a pipeline config from normalized map data" do
    assert {:ok, config} = PipelineConfigBuilder.build(base_map())
    assert config.name == "perme8-core"
    assert Enum.map(config.stages, & &1.id) == ["warm-pool", "test", "deploy"]
  end

  test "returns validation errors for invalid nested step data" do
    invalid =
      put_in(base_map(), ["pipeline", "stages", Access.at(1), "steps", Access.at(0), "run"], nil)

    assert {:error, errors} = PipelineConfigBuilder.build(invalid)
    assert "pipeline.stages[1].steps[0].run must be a string" in errors
  end

  defp base_map do
    %{
      "version" => 1,
      "pipeline" => %{
        "name" => "perme8-core",
        "merge_queue" => %{
          "strategy" => "merge_queue",
          "required_stages" => ["test"],
          "required_review" => true
        },
        "deploy_targets" => [
          %{"id" => "dev", "environment" => "development", "provider" => "docker"},
          %{"id" => "prod", "environment" => "production", "provider" => "kubernetes"}
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
            "steps" => [%{"name" => "prestart", "run" => "scripts/warm_pool.sh"}]
          },
          %{
            "id" => "test",
            "type" => "verification",
            "deploy_target" => "dev",
            "steps" => [%{"name" => "unit-tests", "run" => "mix test"}]
          },
          %{
            "id" => "deploy",
            "type" => "deploy",
            "deploy_target" => "prod",
            "steps" => [%{"name" => "deploy", "run" => "scripts/deploy.sh"}]
          }
        ]
      }
    }
  end
end
