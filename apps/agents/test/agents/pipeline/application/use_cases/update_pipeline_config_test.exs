defmodule Agents.Pipeline.Application.UseCases.UpdatePipelineConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.UpdatePipelineConfig
  alias Agents.Pipeline.Application.PipelineConfigBuilder

  defmodule PipelineConfigRepoStub do
    def get_current do
      case Process.get({__MODULE__, :current}) do
        nil -> {:error, :not_found}
        current -> {:ok, current}
      end
    end

    def upsert_current(config) do
      Process.put({__MODULE__, :current}, config)
      {:ok, config}
    end
  end

  describe "execute/2" do
    test "applies partial step edits including conditions and persists" do
      seed_repo()

      updates = %{
        "stages" => [
          %{
            "id" => "test",
            "steps" => [
              %{
                "name" => "unit-tests",
                "run" => "mix test --trace",
                "timeout_seconds" => 600,
                "conditions" => "branch == main"
              }
            ]
          }
        ]
      }

      assert {:ok, result} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      stage = Enum.find(result.pipeline_config.stages, &(&1.id == "test"))
      [step] = stage.steps
      assert step.run == "mix test --trace"
      assert step.timeout_seconds == 600
      assert step.conditions == "branch == main"

      assert {:ok, persisted} = PipelineConfigRepoStub.get_current()
      persisted_stage = Enum.find(persisted.stages, &(&1.id == "test"))
      assert hd(persisted_stage.steps).run == "mix test --trace"
    end

    test "applies add remove and reorder stage updates" do
      seed_repo()

      updates = %{
        "replace_stages" => true,
        "stages" => [
          %{
            "id" => "security-scan",
            "type" => "verification",
            "steps" => [%{"name" => "credo", "run" => "mix credo --strict"}]
          },
          %{"id" => "warm-pool"},
          %{"id" => "deploy"}
        ]
      }

      assert {:ok, result} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      assert Enum.map(result.pipeline_config.stages, & &1.id) == [
               "security-scan",
               "warm-pool",
               "deploy"
             ]

      assert {:ok, persisted} = PipelineConfigRepoStub.get_current()
      assert Enum.map(persisted.stages, & &1.id) == ["security-scan", "warm-pool", "deploy"]
    end

    test "applies add remove and reorder step updates in a stage" do
      seed_repo()

      updates = %{
        "stages" => [
          %{
            "id" => "warm-pool",
            "replace_steps" => true,
            "steps" => [
              %{"name" => "prestart", "run" => "scripts/warm_pool.sh", "retries" => 1},
              %{"name" => "deps", "run" => "mix deps.get"}
            ]
          }
        ]
      }

      assert {:ok, result} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      warm_pool = Enum.find(result.pipeline_config.stages, &(&1.id == "warm-pool"))
      assert Enum.map(warm_pool.steps, & &1.name) == ["prestart", "deps"]
      assert hd(warm_pool.steps).retries == 1
    end

    test "applies warm pool nested config edits" do
      seed_repo()

      updates = %{
        "stages" => [
          %{
            "id" => "warm-pool",
            "warm_pool" => %{
              "target_count" => 5,
              "image" => "ghcr.io/platform-q-ai/agent:stable",
              "readiness" => %{"strategy" => "command_success", "required_step" => "prestart"}
            }
          }
        ]
      }

      assert {:ok, result} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      warm_pool = Enum.find(result.pipeline_config.stages, &(&1.id == "warm-pool"))
      assert warm_pool.config["warm_pool"]["target_count"] == 5
      assert warm_pool.config["warm_pool"]["image"] == "ghcr.io/platform-q-ai/agent:stable"
    end

    test "returns validation errors and does not persist invalid config" do
      seed_repo()

      updates = %{
        "stages" => [%{"id" => "test", "steps" => [%{"name" => "unit-tests", "run" => nil}]}]
      }

      assert {:error, %{errors: errors}} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      assert Enum.any?(errors, &String.contains?(&1, "pipeline.stages[1].steps[0].run"))

      assert {:ok, persisted} = PipelineConfigRepoStub.get_current()
      stage = Enum.find(persisted.stages, &(&1.id == "test"))
      assert hd(stage.steps).run == "mix test"
    end

    test "persists the default pipeline config in Agents.Repo" do
      seed_repo()

      updates = %{
        "stages" => [
          %{
            "id" => "test",
            "steps" => [
              %{
                "name" => "unit-tests",
                "run" => "mix test --trace"
              }
            ]
          }
        ]
      }

      assert {:ok, result} =
               UpdatePipelineConfig.execute(updates, pipeline_config_repo: PipelineConfigRepoStub)

      assert hd(Enum.find(result.pipeline_config.stages, &(&1.id == "test")).steps).run ==
               "mix test --trace"

      assert {:ok, persisted} = PipelineConfigRepoStub.get_current()
      stage = Enum.find(persisted.stages, &(&1.id == "test"))
      assert hd(stage.steps).run == "mix test --trace"
    end
  end

  defp seed_repo do
    assert {:ok, config} = PipelineConfigBuilder.build(base_map())
    Process.put({PipelineConfigRepoStub, :current}, config)
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
            "steps" => [
              %{"name" => "build", "run" => "mix release"},
              %{"name" => "prestart", "run" => "scripts/warm_pool.sh"}
            ]
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
