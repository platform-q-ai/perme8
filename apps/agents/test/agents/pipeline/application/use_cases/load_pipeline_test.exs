defmodule Agents.Pipeline.Application.UseCases.LoadPipelineTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.PipelineConfigBuilder
  alias Agents.Pipeline.Application.UseCases.LoadPipeline

  defmodule PipelineConfigRepoStub do
    def get_current do
      case Process.get({__MODULE__, :current}) do
        nil -> {:error, :not_found}
        current -> {:ok, current}
      end
    end
  end

  describe "execute/1" do
    test "loads the default pipeline from Agents.Repo" do
      {:ok, config} = PipelineConfigBuilder.build(base_map())
      Process.put({PipelineConfigRepoStub, :current}, config)

      assert {:ok, loaded} = LoadPipeline.execute(pipeline_config_repo: PipelineConfigRepoStub)
      assert loaded.name == config.name
      assert Enum.map(loaded.stages, & &1.id) == Enum.map(config.stages, & &1.id)
    end

    test "returns a clear error when the repo-backed pipeline config is missing" do
      Process.delete({PipelineConfigRepoStub, :current})

      assert {:error, [message]} =
               LoadPipeline.execute(pipeline_config_repo: PipelineConfigRepoStub)

      assert message =~ "pipeline config not found in Agents.Repo"
    end
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
            "warm_pool" => %{
              "target_count" => 2,
              "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
              "readiness" => %{"strategy" => "command_success"}
            },
            "steps" => [
              %{"name" => "prestart", "run" => "scripts/warm_pool.sh", "depends_on" => []}
            ]
          }
        ]
      }
    }
  end
end
