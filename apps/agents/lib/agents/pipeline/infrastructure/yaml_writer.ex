defmodule Agents.Pipeline.Infrastructure.YamlWriter do
  @moduledoc """
  Serializes pipeline configuration into YAML with deterministic field ordering.
  """

  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @pipeline_key_order ["name", "description", "merge_queue", "deploy_targets", "stages"]
  @merge_queue_key_order [
    "strategy",
    "required_stages",
    "required_review",
    "pre_merge_validation"
  ]
  @deploy_target_key_order ["id", "environment", "provider", "strategy", "region"]
  @stage_key_order ["id", "type", "deploy_target", "schedule", "steps", "gates"]
  @step_key_order ["name", "run", "timeout_seconds", "retries", "conditions", "env"]
  @gate_key_order ["type", "required"]

  @spec dump(PipelineConfig.t() | map()) :: {:ok, String.t()} | {:error, [String.t()]}
  def dump(%PipelineConfig{} = config), do: config |> from_pipeline_config() |> dump()

  def dump(%{} = input) do
    yaml_map = normalize_input(input)
    yaml = encode_root(yaml_map) |> Enum.join("\n") |> Kernel.<>("\n")
    {:ok, yaml}
  rescue
    error -> {:error, ["unable to serialize pipeline config: #{Exception.message(error)}"]}
  end

  def dump(_), do: {:error, ["pipeline config must be a map or PipelineConfig struct"]}

  @spec from_pipeline_config(PipelineConfig.t()) :: map()
  def from_pipeline_config(%PipelineConfig{} = config) do
    %{
      "version" => config.version,
      "pipeline" => %{
        "name" => config.name,
        "description" => config.description,
        "merge_queue" => config.merge_queue,
        "deploy_targets" => Enum.map(config.deploy_targets, &deploy_target_to_map/1),
        "stages" => Enum.map(config.stages, &stage_to_map/1)
      }
    }
  end

  defp normalize_input(%{"version" => _version, "pipeline" => _pipeline} = map), do: map

  defp normalize_input(%{version: _version} = map) do
    %{
      "version" => Map.get(map, :version),
      "pipeline" => %{
        "name" => Map.get(map, :name),
        "description" => Map.get(map, :description),
        "merge_queue" => Map.get(map, :merge_queue, %{}),
        "deploy_targets" => Map.get(map, :deploy_targets, []),
        "stages" => Map.get(map, :stages, [])
      }
    }
  end

  defp normalize_input(map), do: stringify_keys(map)

  defp deploy_target_to_map(target) do
    base = %{
      "id" => target.id,
      "environment" => target.environment,
      "provider" => target.provider,
      "strategy" => target.strategy,
      "region" => target.region
    }

    Map.merge(base, target.config || %{})
  end

  defp stage_to_map(stage) do
    base = %{
      "id" => stage.id,
      "type" => stage.type,
      "deploy_target" => stage.deploy_target,
      "schedule" => stage.schedule,
      "steps" => Enum.map(stage.steps, &step_to_map/1),
      "gates" => Enum.map(stage.gates, &gate_to_map/1)
    }

    Map.merge(base, stage.config || %{})
  end

  defp step_to_map(step) do
    %{
      "name" => step.name,
      "run" => step.run,
      "timeout_seconds" => step.timeout_seconds,
      "retries" => step.retries,
      "conditions" => Map.get(step, :conditions),
      "env" => step.env || %{}
    }
  end

  defp gate_to_map(gate),
    do: Map.merge(%{"type" => gate.type, "required" => gate.required}, gate.params)

  defp encode_root(yaml_map) do
    version = Map.get(yaml_map, "version")
    pipeline = stringify_keys(Map.get(yaml_map, "pipeline", %{}))

    ["version: #{scalar(version)}", "pipeline:"] ++ encode_pipeline(pipeline, 2)
  end

  defp encode_pipeline(pipeline, indent) do
    keys = ordered_keys(pipeline, @pipeline_key_order)

    Enum.flat_map(keys, fn key ->
      value = Map.get(pipeline, key)

      cond do
        key == "merge_queue" and is_map(value) and map_size(value) > 0 ->
          [line(indent, "merge_queue:")] ++
            encode_map_with_order(stringify_keys(value), indent + 2, @merge_queue_key_order)

        key == "deploy_targets" and is_list(value) and value != [] ->
          [line(indent, "deploy_targets:")] ++
            encode_ordered_map_list(value, indent + 2, @deploy_target_key_order)

        key == "stages" and is_list(value) and value != [] ->
          [line(indent, "stages:")] ++ encode_stages(value, indent + 2)

        present_scalar?(value) ->
          [line(indent, "#{key}: #{scalar(value)}")]

        true ->
          []
      end
    end)
  end

  defp encode_stages(stages, indent) do
    Enum.flat_map(stages, fn stage ->
      stage = stringify_keys(stage)
      keys = ordered_keys(stage, @stage_key_order ++ remaining_stage_keys(stage))

      Enum.with_index(keys)
      |> Enum.flat_map(fn {key, index} ->
        prefix = if index == 0, do: "- ", else: ""
        item_indent = if index == 0, do: indent, else: indent + 2
        value = Map.get(stage, key)

        cond do
          key == "steps" and is_list(value) and value != [] ->
            [line(item_indent, "#{prefix}steps:")] ++ encode_steps(value, item_indent + 2)

          key == "gates" and is_list(value) and value != [] ->
            [line(item_indent, "#{prefix}gates:")] ++ encode_gates(value, item_indent + 2)

          is_map(value) and map_size(value) > 0 ->
            [line(item_indent, "#{prefix}#{key}:")] ++ encode_generic_map(value, item_indent + 2)

          present_scalar?(value) ->
            [line(item_indent, "#{prefix}#{key}: #{scalar(value)}")]

          true ->
            []
        end
      end)
    end)
  end

  defp encode_steps(steps, indent) do
    Enum.flat_map(steps, fn step ->
      step = stringify_keys(step)
      keys = ordered_keys(step, @step_key_order)

      Enum.with_index(keys)
      |> Enum.flat_map(fn {key, index} ->
        prefix = if index == 0, do: "- ", else: ""
        item_indent = if index == 0, do: indent, else: indent + 2
        value = Map.get(step, key)

        cond do
          key == "env" and is_map(value) and map_size(value) > 0 ->
            [line(item_indent, "#{prefix}env:")] ++ encode_generic_map(value, item_indent + 2)

          present_scalar?(value) ->
            [line(item_indent, "#{prefix}#{key}: #{scalar(value)}")]

          true ->
            []
        end
      end)
    end)
  end

  defp encode_gates(gates, indent) do
    Enum.flat_map(gates, fn gate ->
      gate = stringify_keys(gate)
      keys = ordered_keys(gate, @gate_key_order ++ remaining_gate_keys(gate))

      Enum.with_index(keys)
      |> Enum.flat_map(fn {key, index} ->
        prefix = if index == 0, do: "- ", else: ""
        item_indent = if index == 0, do: indent, else: indent + 2
        value = Map.get(gate, key)

        cond do
          is_map(value) and map_size(value) > 0 ->
            [line(item_indent, "#{prefix}#{key}:")] ++ encode_generic_map(value, item_indent + 2)

          is_list(value) and value != [] ->
            [line(item_indent, "#{prefix}#{key}:")] ++ encode_scalar_list(value, item_indent + 2)

          present_scalar?(value) ->
            [line(item_indent, "#{prefix}#{key}: #{scalar(value)}")]

          true ->
            []
        end
      end)
    end)
  end

  defp encode_ordered_map_list(list, indent, key_order) do
    Enum.flat_map(list, fn item ->
      map = stringify_keys(item)
      keys = ordered_keys(map, key_order)

      Enum.with_index(keys)
      |> Enum.flat_map(fn {key, index} ->
        prefix = if index == 0, do: "- ", else: ""
        item_indent = if index == 0, do: indent, else: indent + 2
        value = Map.get(map, key)

        if present_scalar?(value),
          do: [line(item_indent, "#{prefix}#{key}: #{scalar(value)}")],
          else: []
      end)
    end)
  end

  defp encode_map_with_order(map, indent, key_order) do
    keys = ordered_keys(map, key_order)

    Enum.flat_map(keys, fn key ->
      value = Map.get(map, key)

      cond do
        is_map(value) and map_size(value) > 0 ->
          [line(indent, "#{key}:")] ++ encode_generic_map(value, indent + 2)

        is_list(value) and value != [] ->
          [line(indent, "#{key}:")] ++ encode_scalar_list(value, indent + 2)

        present_scalar?(value) ->
          [line(indent, "#{key}: #{scalar(value)}")]

        true ->
          []
      end
    end)
  end

  defp encode_generic_map(map, indent) do
    map = stringify_keys(map)

    map
    |> Map.keys()
    |> Enum.sort()
    |> Enum.flat_map(fn key ->
      value = Map.get(map, key)

      cond do
        is_map(value) and map_size(value) > 0 ->
          [line(indent, "#{key}:")] ++ encode_generic_map(value, indent + 2)

        is_list(value) and value != [] ->
          [line(indent, "#{key}:")] ++ encode_scalar_list(value, indent + 2)

        present_scalar?(value) ->
          [line(indent, "#{key}: #{scalar(value)}")]

        true ->
          []
      end
    end)
  end

  defp encode_scalar_list(list, indent), do: Enum.map(list, &line(indent, "- #{scalar(&1)}"))

  defp ordered_keys(map, preferred) do
    keys = Map.keys(map)
    preferred_present = Enum.filter(preferred, &(&1 in keys))
    preferred_present ++ Enum.sort(keys -- preferred_present)
  end

  defp remaining_stage_keys(stage_map),
    do: stage_map |> Map.keys() |> Enum.reject(&(&1 in @stage_key_order))

  defp remaining_gate_keys(gate), do: gate |> Map.keys() |> Enum.reject(&(&1 in @gate_key_order))

  defp line(indent, content), do: "#{String.duplicate(" ", indent)}#{content}"
  defp present_scalar?(value), do: not is_nil(value) and not is_map(value) and not is_list(value)

  defp scalar(value) when is_binary(value), do: maybe_quote_string(value)
  defp scalar(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp scalar(value) when is_integer(value), do: Integer.to_string(value)
  defp scalar(value) when is_float(value), do: Float.to_string(value)
  defp scalar(nil), do: "null"
  defp scalar(value), do: value |> to_string() |> maybe_quote_string()

  defp maybe_quote_string(value) do
    if String.trim(value) == value and value != "" and
         String.match?(value, ~r/^[A-Za-z0-9._\/-]+(?: [A-Za-z0-9._\/-]+)*$/) do
      value
    else
      escaped = value |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")
      "\"#{escaped}\""
    end
  end

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), stringify_nested(value)} end)
    |> Map.new()
  end

  defp stringify_keys(other), do: other
  defp stringify_nested(value) when is_map(value), do: stringify_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value
end
