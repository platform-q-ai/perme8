defmodule Agents.Pipeline.Application.UseCases.TriggerPipelineRun do
  @moduledoc "Creates a pipeline run for a trigger and optionally starts execution."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.UseCases.RunStage
  alias Agents.Pipeline.Domain.Entities.PipelineRun

  @spec execute(map(), keyword()) :: {:ok, PipelineRun.t()} | {:ok, nil} | {:error, term()}
  def execute(attrs, opts \\ []) when is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    pipeline_path = Keyword.get(opts, :pipeline_path, default_pipeline_path())
    auto_run? = Keyword.get(opts, :auto_run, true)

    with {:ok, config} <- load_pipeline(pipeline_path, opts) do
      stage_ids = select_stage_ids(config.stages, trigger_type(attrs))

      if stage_ids == [] do
        {:ok, nil}
      else
        run_attrs = %{
          trigger_type: trigger_type(attrs),
          trigger_reference: trigger_reference(attrs),
          task_id: Map.get(attrs, :task_id) || Map.get(attrs, "task_id"),
          session_id: Map.get(attrs, :session_id) || Map.get(attrs, "session_id"),
          pull_request_number:
            Map.get(attrs, :pull_request_number) || Map.get(attrs, "pull_request_number"),
          status: "idle",
          remaining_stage_ids: stage_ids,
          stage_results: %{}
        }

        with {:ok, run} <- repo_module.create_run(run_attrs) do
          if auto_run? do
            RunStage.execute(run.id, opts)
          else
            {:ok, PipelineRun.from_schema(run)}
          end
        end
      end
    end
  end

  defp trigger_type(attrs) do
    Map.get(attrs, :trigger_type) || Map.get(attrs, "trigger_type") ||
      infer_trigger_from_event(Map.get(attrs, :event))
  end

  defp trigger_reference(attrs) do
    Map.get(attrs, :trigger_reference) ||
      Map.get(attrs, "trigger_reference") ||
      Map.get(attrs, :task_id) ||
      Map.get(attrs, "task_id") ||
      to_string(
        Map.get(attrs, :pull_request_number) || Map.get(attrs, "pull_request_number") || "unknown"
      )
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

  defp select_stage_ids(stages, "on_session_complete") do
    stages |> Enum.filter(&(&1.type == "verification")) |> Enum.map(& &1.id)
  end

  defp select_stage_ids(stages, "on_pull_request") do
    stages |> Enum.filter(&(&1.type == "verification")) |> Enum.map(& &1.id)
  end

  defp select_stage_ids(stages, "on_merge") do
    stages |> Enum.filter(&(&1.type == "deploy")) |> Enum.map(& &1.id)
  end

  defp select_stage_ids(_stages, _trigger_type), do: []

  defp load_pipeline(path, opts) do
    parser = Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser())
    parser.parse_file(path)
  end

  defp default_pipeline_path do
    Path.expand("../../../../../../../perme8-pipeline.yml", __DIR__)
  end
end
