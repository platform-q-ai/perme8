defmodule Agents.Pipeline.Application.PipelineConfigBuilderTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.PipelineConfigBuilder

  test "builds a pipeline config from normalized map data" do
    assert {:ok, config} = PipelineConfigBuilder.build(base_map())
    assert config.name == "perme8-core"
    assert Enum.map(config.stages, & &1.id) == ["warm-pool", "test", "merge-queue", "deploy"]
  end

  test "returns validation errors for invalid nested step data" do
    invalid =
      put_in(base_map(), ["pipeline", "stages", Access.at(1), "steps", Access.at(0), "run"], nil)

    assert {:error, errors} = PipelineConfigBuilder.build(invalid)
    assert "pipeline.stages[1].steps[0].run must be a string" in errors
  end

  test "requires at least one entry stage with triggers" do
    invalid = put_in(base_map(), ["pipeline", "stages", Access.at(0), "triggers"], [])

    assert {:error, errors} = PipelineConfigBuilder.build(invalid)
    assert "pipeline must define at least one entry stage with triggers" in errors
  end

  defp base_map do
    %{
      "version" => 1,
      "pipeline" => %{
        "name" => "perme8-core",
        "stages" => [
          %{
            "id" => "warm-pool",
            "type" => "warm_pool",
            "schedule" => %{"cron" => "*/5 * * * *"},
            "triggers" => ["on_ticket_play"],
            "ticket_concurrency" => 1,
            "ticket_stage" => "in_progress",
            "warm_pool" => %{
              "target_count" => 2,
              "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
              "readiness" => %{"strategy" => "command_success"}
            },
            "steps" => [
              %{"name" => "prestart", "run" => "scripts/warm_pool.sh", "depends_on" => []}
            ]
          },
          %{
            "id" => "test",
            "type" => "verification",
            "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
          },
          %{
            "id" => "merge-queue",
            "type" => "automation",
            "schedule" => %{"cron" => "*/10 * * * *"},
            "triggers" => ["on_merge_window"],
            "ticket_concurrency" => 0,
            "ticket_stage" => "merge_queue",
            "steps" => [
              %{"name" => "merge-batch", "run" => "scripts/merge_queue.sh", "depends_on" => []}
            ]
          },
          %{
            "id" => "deploy",
            "type" => "automation",
            "steps" => [%{"name" => "deploy", "run" => "scripts/deploy.sh", "depends_on" => []}]
          }
        ]
      }
    }
  end
end
