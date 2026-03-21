defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineRunRepository do
  @moduledoc "Persistence operations for pipeline runs."

  @behaviour Agents.Pipeline.Application.Behaviours.PipelineRunRepositoryBehaviour

  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema
  alias Agents.Repo

  @impl true
  def create_run(attrs, repo \\ Repo) do
    %PipelineRunSchema{}
    |> PipelineRunSchema.changeset(attrs)
    |> repo.insert()
  end

  @impl true
  def get_run(id, repo \\ Repo) do
    case repo.get(PipelineRunSchema, id) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  @impl true
  def update_run(id, attrs, repo \\ Repo) do
    case repo.get(PipelineRunSchema, id) do
      nil -> {:error, :not_found}
      run -> run |> PipelineRunSchema.changeset(attrs) |> repo.update()
    end
  end
end
