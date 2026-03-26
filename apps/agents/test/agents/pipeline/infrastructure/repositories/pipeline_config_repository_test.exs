defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Application.PipelineConfigBuilder
  alias Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepository
  alias Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema

  test "creates and updates the current pipeline config through Agents.Repo" do
    assert {:ok, initial} = PipelineConfigRepository.get_current()
    assert initial.name == "perme8-core"

    assert {:ok, updated_config} =
             PipelineConfigBuilder.build(%{
               "version" => 1,
               "pipeline" => %{
                 "name" => "repo-backed",
                 "deploy_targets" => [
                   %{"id" => "dev", "environment" => "development", "provider" => "docker"}
                 ],
                 "stages" => [
                   %{
                     "id" => "warm-pool",
                     "type" => "warm_pool",
                     "deploy_target" => "dev",
                     "schedule" => %{"cron" => "*/5 * * * *"},
                     "warm_pool" => %{
                       "target_count" => 3,
                       "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
                       "readiness" => %{"strategy" => "command_success"}
                     },
                     "steps" => [%{"name" => "prestart", "run" => "scripts/warm_pool.sh"}]
                   }
                 ]
               }
             })

    assert {:ok, persisted} = PipelineConfigRepository.upsert_current(updated_config)
    assert persisted.name == "repo-backed"
    assert hd(persisted.stages).config["warm_pool"]["target_count"] == 3

    schema = Repo.get_by!(PipelineConfigSchema, slug: PipelineConfigRepository.current_slug())
    assert schema.name == "repo-backed"
    assert schema.version == 1
    assert schema.merge_queue == %{}

    assert {:ok, fetched} = PipelineConfigRepository.get_current()
    assert fetched.name == "repo-backed"
    assert hd(fetched.stages).steps |> hd() |> Map.get(:run) == "scripts/warm_pool.sh"
  end
end
