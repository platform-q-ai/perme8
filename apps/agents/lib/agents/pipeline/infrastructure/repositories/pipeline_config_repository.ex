defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineConfigRepository do
  @moduledoc "Persistence operations for the current pipeline configuration."

  import Ecto.Query

  alias Agents.Pipeline.Application.PipelineConfigMapper
  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  alias Agents.Pipeline.Infrastructure.Schemas.{
    PipelineConfigSchema,
    PipelineGateSchema,
    PipelineStageSchema,
    PipelineStepSchema
  }

  alias Agents.Repo
  alias Ecto.Multi

  @current_slug "current"

  @spec current_slug() :: String.t()
  def current_slug, do: @current_slug

  @spec get_current(module()) :: {:ok, PipelineConfig.t()} | {:error, :not_found}
  def get_current(repo \\ Repo) do
    case repo.get_by(PipelineConfigSchema, slug: @current_slug) do
      nil ->
        {:error, :not_found}

      config ->
        {:ok, config |> preload_current(repo) |> PipelineConfigMapper.from_persistence_record()}
    end
  end

  @spec upsert_current(PipelineConfig.t(), module()) ::
          {:ok, PipelineConfig.t()} | {:error, Ecto.Changeset.t() | term()}
  def upsert_current(%PipelineConfig{} = config, repo \\ Repo) do
    attrs = PipelineConfigMapper.to_persistence_attrs(config)

    Multi.new()
    |> Multi.run(:pipeline_config, fn repo, _changes -> upsert_root(repo, attrs) end)
    |> Multi.run(:children, fn repo, %{pipeline_config: root} ->
      replace_children(repo, root.id, attrs)
    end)
    |> Multi.run(:loaded, fn repo, %{pipeline_config: root} ->
      {:ok, root |> load_by_id(repo) |> PipelineConfigMapper.from_persistence_record()}
    end)
    |> repo.transaction()
    |> case do
      {:ok, %{loaded: loaded}} -> {:ok, loaded}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp upsert_root(repo, attrs) do
    root_attrs = Map.take(attrs, [:slug, :version, :name, :description, :merge_queue])

    case repo.get_by(PipelineConfigSchema, slug: @current_slug) do
      nil ->
        %PipelineConfigSchema{}
        |> PipelineConfigSchema.changeset(root_attrs)
        |> repo.insert()

      config ->
        config
        |> PipelineConfigSchema.changeset(root_attrs)
        |> repo.update()
    end
  end

  defp replace_children(repo, pipeline_config_id, attrs) do
    repo.delete_all(
      from(stage in PipelineStageSchema, where: stage.pipeline_config_id == ^pipeline_config_id)
    )

    with :ok <- insert_stages(repo, pipeline_config_id, attrs.stages) do
      {:ok, :replaced}
    end
  end

  defp insert_stages(repo, pipeline_config_id, stages) do
    Enum.reduce_while(stages, :ok, fn attrs, _acc ->
      stage_attrs =
        attrs
        |> Map.drop([:steps, :gates])
        |> Map.put(:pipeline_config_id, pipeline_config_id)

      with {:ok, stage} <-
             %PipelineStageSchema{}
             |> PipelineStageSchema.changeset(stage_attrs)
             |> repo.insert(),
           :ok <- insert_steps(repo, stage.id, attrs.steps),
           :ok <- insert_gates(repo, stage.id, attrs.gates) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_steps(repo, pipeline_stage_id, steps) do
    Enum.reduce_while(steps, :ok, fn attrs, _acc ->
      attrs = Map.put(attrs, :pipeline_stage_id, pipeline_stage_id)

      case %PipelineStepSchema{}
           |> PipelineStepSchema.changeset(attrs)
           |> repo.insert() do
        {:ok, _step} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_gates(repo, pipeline_stage_id, gates) do
    Enum.reduce_while(gates, :ok, fn attrs, _acc ->
      attrs = Map.put(attrs, :pipeline_stage_id, pipeline_stage_id)

      case %PipelineGateSchema{}
           |> PipelineGateSchema.changeset(attrs)
           |> repo.insert() do
        {:ok, _gate} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp load_by_id(%PipelineConfigSchema{id: id}, repo), do: load_by_id(id, repo)

  defp load_by_id(id, repo) do
    repo.get!(PipelineConfigSchema, id)
    |> preload_current(repo)
  end

  defp preload_current(config, repo) do
    steps_query = from(step in PipelineStepSchema, order_by: step.position)
    gates_query = from(gate in PipelineGateSchema, order_by: gate.position)

    stages_query =
      from(stage in PipelineStageSchema,
        order_by: stage.position,
        preload: [steps: ^steps_query, gates: ^gates_query]
      )

    repo.preload(config, stages: stages_query)
  end
end
