defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepository
  alias Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema

  test "creates and updates the current pipeline config through Agents.Repo" do
    assert {:error, :not_found} = PipelineConfigRepository.get_current()

    assert {:ok, created} = PipelineConfigRepository.upsert_current(%{yaml: "version: 1\n"})
    assert created.slug == PipelineConfigRepository.current_slug()

    assert {:ok, fetched} = PipelineConfigRepository.get_current()
    assert fetched.id == created.id
    assert fetched.yaml == "version: 1\n"

    assert {:ok, updated} = PipelineConfigRepository.upsert_current(%{yaml: "version: 2\n"})
    assert updated.id == created.id

    persisted = Repo.get!(PipelineConfigSchema, created.id)
    assert persisted.yaml == "version: 2\n"
  end
end
