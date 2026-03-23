defmodule Agents.Pipeline.Application.UseCases.UpdatePipelineConfig do
  @moduledoc """
  Applies editable pipeline configuration updates, validates via parser, and persists YAML.
  """

  alias Agents.Pipeline.Application.PipelineRuntimeConfig

  @default_path "perme8-pipeline.yml"

  @spec execute(map(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(updates, opts \\ [])

  def execute(updates, opts) when is_map(updates) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())
    writer = Keyword.get(opts, :writer, pipeline_writer())
    path = Keyword.get(opts, :pipeline_path, @default_path)
    file_io = Keyword.get(opts, :file_io, File)

    with {:ok, current_config} <- parser.parse_file(path),
         current_map <- pipeline_config_to_map(current_config),
         merged_map <- merge_updates(current_map, updates),
         {:ok, yaml} <- writer.dump(merged_map),
         {:ok, validated_config} <- parser.parse_string(yaml),
         :ok <- write_file(file_io, path, yaml) do
      {:ok,
       %{
         pipeline_config: validated_config,
         editable_config: editable_projection(merged_map),
         yaml: yaml,
         path: path
       }}
    else
      {:error, errors} when is_list(errors) ->
        merged_map = safe_merge_preview(opts, updates)
        {:error, %{errors: errors, editable_config: editable_projection(merged_map)}}

      {:error, reason} ->
        {:error, %{errors: [to_string(reason)], editable_config: editable_projection(%{})}}
    end
  end

  def execute(_updates, _opts), do: {:error, %{errors: ["updates must be a map"]}}

  defp pipeline_writer do
    if function_exported?(PipelineRuntimeConfig, :pipeline_writer, 0) do
      PipelineRuntimeConfig.pipeline_writer()
    else
      :"Elixir.Agents.Pipeline.Infrastructure.YamlWriter"
    end
  end

  defp safe_merge_preview(opts, updates) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())
    path = Keyword.get(opts, :pipeline_path, @default_path)

    case parser.parse_file(path) do
      {:ok, config} -> config |> pipeline_config_to_map() |> merge_updates(updates)
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp write_file(%{write: write_fun}, path, yaml) when is_function(write_fun, 2),
    do: write_fun.(path, yaml)

  defp write_file(file_module, path, yaml) do
    case file_module.write(path, yaml) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to write pipeline file: #{inspect(reason)}"}
    end
  end

  defp merge_updates(current_map, updates) do
    current = stringify_keys(current_map)
    updates = stringify_keys(updates)

    pipeline_updates =
      if Map.has_key?(updates, "pipeline"), do: updates["pipeline"], else: updates

    current
    |> Map.update!("pipeline", fn pipeline ->
      pipeline
      |> apply_root_updates(pipeline_updates)
      |> apply_stage_updates(pipeline_updates)
    end)
  end

  defp apply_root_updates(pipeline, updates) do
    root_keys = ["name", "description", "merge_queue", "deploy_targets"]

    Enum.reduce(root_keys, pipeline, fn key, acc ->
      if Map.has_key?(updates, key), do: Map.put(acc, key, updates[key]), else: acc
    end)
  end

  defp apply_stage_updates(pipeline, updates) do
    if Map.has_key?(updates, "stages") do
      stages = Map.get(pipeline, "stages", [])

      merged_stages =
        if truthy?(updates["replace_stages"]) do
          build_replaced_stages(stages, updates["stages"])
        else
          merge_partial_stages(stages, updates["stages"])
        end

      Map.put(pipeline, "stages", merged_stages)
    else
      pipeline
    end
  end

  defp build_replaced_stages(existing_stages, updates) do
    Enum.map(updates || [], fn stage_update ->
      stage_update = stringify_keys(stage_update)
      stage_id = stage_update["id"]

      existing =
        Enum.find(existing_stages, &(Map.get(stringify_keys(&1), "id") == stage_id)) || %{}

      merge_stage(existing, stage_update)
    end)
  end

  defp merge_partial_stages(existing_stages, updates) do
    updates = Enum.map(updates || [], &stringify_keys/1)

    merged_existing =
      Enum.map(existing_stages, fn stage ->
        stage = stringify_keys(stage)
        stage_id = stage["id"]

        case Enum.find(updates, &(&1["id"] == stage_id)) do
          nil -> stage
          stage_update -> merge_stage(stage, stage_update)
        end
      end)

    new_stages =
      Enum.filter(updates, fn update ->
        update_id = update["id"]
        Enum.all?(existing_stages, &(Map.get(stringify_keys(&1), "id") != update_id))
      end)

    merged_existing ++ Enum.map(new_stages, &merge_stage(%{}, &1))
  end

  defp merge_stage(existing, update) do
    existing = stringify_keys(existing)
    update = stringify_keys(update)

    merged = deep_merge(existing, Map.drop(update, ["steps", "gates", "replace_steps"]))

    merged
    |> merge_stage_steps(existing, update)
    |> merge_stage_gates(existing, update)
  end

  defp merge_stage_steps(merged, existing, update) do
    if Map.has_key?(update, "steps") do
      existing_steps = Map.get(existing, "steps", [])
      incoming = Enum.map(update["steps"] || [], &stringify_keys/1)

      steps =
        if truthy?(update["replace_steps"]) do
          Enum.map(incoming, fn step_update ->
            existing_step =
              Enum.find(
                existing_steps,
                &(Map.get(stringify_keys(&1), "name") == step_update["name"])
              ) || %{}

            deep_merge(stringify_keys(existing_step), step_update)
          end)
        else
          merge_partial_steps(existing_steps, incoming)
        end

      Map.put(merged, "steps", steps)
    else
      merged
    end
  end

  defp merge_stage_gates(merged, _existing, update) do
    if Map.has_key?(update, "gates"), do: Map.put(merged, "gates", update["gates"]), else: merged
  end

  defp merge_partial_steps(existing_steps, incoming_updates) do
    merged =
      Enum.map(existing_steps, fn step ->
        step = stringify_keys(step)
        step_name = step["name"]

        case Enum.find(incoming_updates, &(&1["name"] == step_name)) do
          nil -> step
          step_update -> deep_merge(step, step_update)
        end
      end)

    new_steps =
      Enum.filter(incoming_updates, fn update ->
        update_name = update["name"]
        Enum.all?(existing_steps, &(Map.get(stringify_keys(&1), "name") != update_name))
      end)

    merged ++ new_steps
  end

  defp editable_projection(%{"version" => version, "pipeline" => pipeline}) do
    pipeline = stringify_keys(pipeline)

    %{
      "version" => version,
      "name" => Map.get(pipeline, "name"),
      "description" => Map.get(pipeline, "description"),
      "merge_queue" => Map.get(pipeline, "merge_queue", %{}),
      "deploy_targets" => Map.get(pipeline, "deploy_targets", []),
      "stages" => Map.get(pipeline, "stages", [])
    }
  end

  defp editable_projection(_), do: %{}

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(_left, right), do: right

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), stringify_nested(value)} end)
    |> Map.new()
  end

  defp stringify_keys(other), do: other

  defp stringify_nested(value) when is_map(value), do: stringify_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value

  defp pipeline_config_to_map(config) do
    %{
      "version" => config.version,
      "pipeline" => %{
        "name" => config.name,
        "description" => config.description,
        "merge_queue" => config.merge_queue,
        "deploy_targets" =>
          Enum.map(config.deploy_targets, fn target ->
            %{
              "id" => target.id,
              "environment" => target.environment,
              "provider" => target.provider,
              "strategy" => target.strategy,
              "region" => target.region
            }
            |> Map.merge(target.config || %{})
          end),
        "stages" =>
          Enum.map(config.stages, fn stage ->
            %{
              "id" => stage.id,
              "type" => stage.type,
              "deploy_target" => stage.deploy_target,
              "schedule" => stage.schedule,
              "steps" =>
                Enum.map(stage.steps, fn step ->
                  %{
                    "name" => step.name,
                    "run" => step.run,
                    "timeout_seconds" => step.timeout_seconds,
                    "retries" => step.retries,
                    "conditions" => Map.get(step, :conditions),
                    "env" => step.env
                  }
                end),
              "gates" =>
                Enum.map(stage.gates, fn gate ->
                  Map.merge(%{"type" => gate.type, "required" => gate.required}, gate.params)
                end)
            }
            |> Map.merge(stage.config || %{})
          end)
      }
    }
  end
end
