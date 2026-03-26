defmodule Agents.Pipeline.Application.UseCases.UpdatePipelineConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.UpdatePipelineConfig
  alias Agents.Pipeline.Infrastructure.YamlParser

  defmodule PipelineConfigRepoStub do
    def get_current do
      case Process.get({__MODULE__, :current}) do
        nil -> {:error, :not_found}
        current -> {:ok, current}
      end
    end

    def upsert_current(attrs) do
      current = %{yaml: Map.get(attrs, :yaml) || Map.get(attrs, "yaml")}
      Process.put({__MODULE__, :current}, current)
      {:ok, current}
    end
  end

  describe "execute/2" do
    test "applies partial step edits including conditions and persists" do
      path = write_tmp_file(base_yaml())

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

      assert {:ok, result} = UpdatePipelineConfig.execute(updates, pipeline_path: path)

      stage = Enum.find(result.pipeline_config.stages, &(&1.id == "test"))
      [step] = stage.steps
      assert step.run == "mix test --trace"
      assert step.timeout_seconds == 600
      assert step.conditions == "branch == main"

      assert {:ok, reparsed} = YamlParser.parse_file(path)
      reparsed_stage = Enum.find(reparsed.stages, &(&1.id == "test"))
      assert hd(reparsed_stage.steps).run == "mix test --trace"
    end

    test "applies add remove and reorder stage updates" do
      path = write_tmp_file(base_yaml())

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

      assert {:ok, result} = UpdatePipelineConfig.execute(updates, pipeline_path: path)

      assert Enum.map(result.pipeline_config.stages, & &1.id) == [
               "security-scan",
               "warm-pool",
               "deploy"
             ]

      assert {:ok, reparsed} = YamlParser.parse_file(path)
      assert Enum.map(reparsed.stages, & &1.id) == ["security-scan", "warm-pool", "deploy"]
    end

    test "applies add remove and reorder step updates in a stage" do
      path = write_tmp_file(base_yaml())

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

      assert {:ok, result} = UpdatePipelineConfig.execute(updates, pipeline_path: path)

      warm_pool = Enum.find(result.pipeline_config.stages, &(&1.id == "warm-pool"))
      assert Enum.map(warm_pool.steps, & &1.name) == ["prestart", "deps"]
      assert hd(warm_pool.steps).retries == 1
    end

    test "applies warm pool nested config edits" do
      path = write_tmp_file(base_yaml())

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

      assert {:ok, result} = UpdatePipelineConfig.execute(updates, pipeline_path: path)

      warm_pool = Enum.find(result.pipeline_config.stages, &(&1.id == "warm-pool"))
      assert warm_pool.config["warm_pool"]["target_count"] == 5
      assert warm_pool.config["warm_pool"]["image"] == "ghcr.io/platform-q-ai/agent:stable"
    end

    test "returns validation errors and does not write invalid config" do
      path = write_tmp_file(base_yaml())
      write_calls = :counters.new(1, [])

      file_io = %{
        write: fn _path, _content ->
          :counters.add(write_calls, 1, 1)
          :ok
        end
      }

      updates = %{
        "stages" => [%{"id" => "test", "steps" => [%{"name" => "unit-tests", "run" => nil}]}]
      }

      assert {:error, %{errors: errors}} =
               UpdatePipelineConfig.execute(updates, pipeline_path: path, file_io: file_io)

      assert Enum.any?(errors, &String.contains?(&1, "pipeline.stages[1].steps[0].run"))
      assert :counters.get(write_calls, 1) == 0

      assert {:ok, persisted} = YamlParser.parse_file(path)
      stage = Enum.find(persisted.stages, &(&1.id == "test"))
      assert hd(stage.steps).run == "mix test"
    end

    test "persists the default pipeline config in Agents.Repo" do
      Process.put({PipelineConfigRepoStub, :current}, %{yaml: base_yaml()})

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
               UpdatePipelineConfig.execute(updates,
                 pipeline_config_repo: PipelineConfigRepoStub
               )

      assert hd(Enum.find(result.pipeline_config.stages, &(&1.id == "test")).steps).run ==
               "mix test --trace"

      assert {:ok, %{yaml: yaml}} = PipelineConfigRepoStub.get_current()
      assert yaml =~ "mix test --trace"
      refute yaml =~ "run: mix test\n"
    end
  end

  defp write_tmp_file(content) do
    path =
      Path.join(System.tmp_dir!(), "pipeline-update-#{System.unique_integer([:positive])}.yml")

    File.write!(path, content)
    path
  end

  defp base_yaml do
    """
    version: 1
    pipeline:
      name: perme8-core
      merge_queue:
        strategy: merge_queue
        required_stages:
          - test
        required_review: true
      deploy_targets:
        - id: dev
          environment: development
          provider: docker
        - id: prod
          environment: production
          provider: kubernetes
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
            - name: build
              run: mix release
            - name: prestart
              run: scripts/warm_pool.sh
        - id: test
          type: verification
          deploy_target: dev
          steps:
            - name: unit-tests
              run: mix test
        - id: deploy
          type: deploy
          deploy_target: prod
          steps:
            - name: deploy
              run: scripts/deploy.sh
    """
  end
end
