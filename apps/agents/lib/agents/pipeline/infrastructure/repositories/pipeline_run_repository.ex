defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineRunRepository do
  @moduledoc "Persistence operations for pipeline runs."

  @behaviour Agents.Pipeline.Application.Behaviours.PipelineRunRepositoryBehaviour

  import Ecto.Query, warn: false

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
  def list_runs_for_pull_request(number, repo \\ Repo) when is_integer(number) do
    PipelineRunSchema
    |> where([run], run.pull_request_number == ^number)
    |> order_by([run], desc: run.inserted_at)
    |> repo.all()
  end

  @impl true
  def count_active_for_stage(stage_id, repo \\ Repo) when is_binary(stage_id) do
    PipelineRunSchema
    |> where([run], run.current_stage_id == ^stage_id)
    |> where([run], run.status in ["running_stage", "awaiting_result"])
    |> repo.aggregate(:count, :id)
  end

  @impl true
  def list_queued_for_stage(stage_id, repo \\ Repo) when is_binary(stage_id) do
    PipelineRunSchema
    |> where([run], run.queued_stage_id == ^stage_id)
    |> where([run], run.status == "queued")
    |> order_by([run], asc: run.enqueued_at, asc: run.inserted_at)
    |> repo.all()
  end

  @impl true
  def update_run(id, attrs, repo \\ Repo) do
    case repo.get(PipelineRunSchema, id) do
      nil -> {:error, :not_found}
      run -> run |> PipelineRunSchema.changeset(attrs) |> repo.update()
    end
  end
end
