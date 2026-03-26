defmodule Agents.Pipeline.Application.UseCases.TriggerPipelineRun do
  @moduledoc "Creates a pipeline run for a trigger and optionally starts execution."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Application.UseCases.RunStage
  alias Agents.Pipeline.Domain.Entities.PipelineRun

  @spec execute(map(), keyword()) :: {:ok, PipelineRun.t()} | {:ok, nil} | {:error, term()}
  def execute(attrs, opts \\ []) when is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    auto_run? = Keyword.get(opts, :auto_run, true)

    with {:ok, config} <- load_pipeline(opts) do
      trigger = trigger_type(attrs)
      stage_ids = select_stage_ids(config.stages, trigger)

      maybe_create_run(
        stage_ids,
        build_run_attrs(attrs, trigger, stage_ids),
        repo_module,
        auto_run?,
        opts
      )
    end
  end

  defp maybe_create_run([], _run_attrs, _repo_module, _auto_run?, _opts), do: {:ok, nil}

  defp maybe_create_run(stage_ids, run_attrs, repo_module, auto_run?, opts)
       when is_list(stage_ids) do
    with {:ok, run} <- repo_module.create_run(run_attrs) do
      if auto_run? do
        RunStage.execute(run.id, opts)
      else
        {:ok, PipelineRun.from_schema(run)}
      end
    end
  end

  defp build_run_attrs(attrs, trigger, stage_ids) do
    %{
      trigger_type: trigger,
      trigger_reference: trigger_reference(attrs),
      task_id: value_from_attrs(attrs, :task_id),
      session_id: value_from_attrs(attrs, :session_id),
      pull_request_number: value_from_attrs(attrs, :pull_request_number),
      source_branch:
        value_from_attrs(attrs, :source_branch) || event_field(attrs, :source_branch),
      target_branch:
        value_from_attrs(attrs, :target_branch) || event_field(attrs, :target_branch),
      status: "idle",
      remaining_stage_ids: stage_ids,
      stage_results: %{}
    }
  end

  defp trigger_type(attrs) do
    value_from_attrs(attrs, :trigger_type) || infer_trigger_from_event(Map.get(attrs, :event))
  end

  defp trigger_reference(attrs) do
    value_from_attrs(attrs, :trigger_reference) ||
      value_from_attrs(attrs, :task_id) ||
      to_string(value_from_attrs(attrs, :pull_request_number) || "unknown")
  end

  defp infer_trigger_from_event(%{event_type: "sessions.task_completed"}),
    do: "on_session_complete"

  defp infer_trigger_from_event(%{event_type: "sessions.session_diff_produced"}),
    do: "on_session_complete"

  defp infer_trigger_from_event(%{event_type: "pipeline.pull_request_created"}),
    do: "on_pull_request"

  defp infer_trigger_from_event(%{event_type: "pipeline.pull_request_updated"}),
    do: "on_pull_request"

  defp infer_trigger_from_event(%{event_type: "pipeline.pull_request_merged"}), do: "on_merge"

  defp infer_trigger_from_event(_), do: "unknown"

  defp event_field(attrs, key) do
    case Map.get(attrs, :event) || Map.get(attrs, "event") do
      nil -> nil
      event -> Map.get(event, key) || Map.get(event, Atom.to_string(key))
    end
  end

  defp value_from_attrs(attrs, key),
    do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp select_stage_ids(stages, trigger_type) do
    dependencies = stage_dependencies(stages)

    root_ids =
      stages
      |> Enum.filter(&(trigger_type in (&1.triggers || [])))
      |> Enum.map(& &1.id)

    reachable_stage_ids(stages, dependencies, root_ids, trigger_type)
  end

  defp stage_dependencies(stages) do
    previous_ids =
      stages
      |> Enum.map(& &1.id)
      |> Enum.with_index()
      |> Map.new()

    Enum.with_index(stages)
    |> Map.new(fn {stage, index} ->
      deps =
        case stage.depends_on || [] do
          [] when index > 0 -> [Enum.at(stages, index - 1).id]
          explicit -> explicit
        end

      {stage.id, Enum.filter(deps, &Map.has_key?(previous_ids, &1))}
    end)
  end

  defp reachable_stage_ids(stages, dependencies, root_ids, trigger_type) do
    stage_ids = Enum.map(stages, & &1.id)
    stages_by_id = Map.new(stages, &{&1.id, &1})

    Enum.reduce(stage_ids, MapSet.new(root_ids), fn stage_id, selected ->
      deps = Map.get(dependencies, stage_id, [])
      stage = Map.get(stages_by_id, stage_id)
      stage_triggers = (stage && stage.triggers) || []
      eligible_by_trigger? = Enum.empty?(stage_triggers) or trigger_type in stage_triggers

      cond do
        MapSet.member?(selected, stage_id) ->
          selected

        deps == [] ->
          selected

        eligible_by_trigger? and Enum.all?(deps, &MapSet.member?(selected, &1)) ->
          MapSet.put(selected, stage_id)

        true ->
          selected
      end
    end)
    |> then(fn selected -> Enum.filter(stage_ids, &MapSet.member?(selected, &1)) end)
  end

  defp load_pipeline(opts),
    do: LoadPipeline.execute(maybe_put([], :pipeline_config_repo, opts[:pipeline_config_repo]))

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
