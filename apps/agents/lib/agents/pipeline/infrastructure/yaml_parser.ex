defmodule Agents.Pipeline.Infrastructure.YamlParser do
  @moduledoc """
  Parses and validates the pipeline YAML DSL.
  """

  @behaviour Agents.Pipeline.Application.Behaviours.PipelineParserBehaviour

  alias Agents.Pipeline.Domain.Entities.{DeployTarget, Gate, PipelineConfig, Stage, Step}

  @doc "Parses a YAML pipeline file into a validated pipeline config."
  @spec parse_file(Path.t()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def parse_file(path) when is_binary(path) do
    with {:ok, parsed} <- decode_file(path) do
      validate(parsed)
    end
  end

  @doc "Parses YAML content into a validated pipeline config."
  @spec parse_string(String.t()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def parse_string(yaml) when is_binary(yaml) do
    with {:ok, parsed} <- decode_string(yaml) do
      validate(parsed)
    end
  end

  defp decode_file(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, reason} -> {:error, ["invalid YAML: #{inspect(reason)}"]}
      data when is_map(data) -> {:ok, data}
      other -> {:error, ["invalid YAML root: expected map, got #{inspect(other)}"]}
    end
  rescue
    error ->
      {:error, ["unable to read YAML file #{path}: #{Exception.message(error)}"]}
  end

  defp decode_string(yaml) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, reason} -> {:error, ["invalid YAML: #{inspect(reason)}"]}
      data when is_map(data) -> {:ok, data}
      other -> {:error, ["invalid YAML root: expected map, got #{inspect(other)}"]}
    end
  rescue
    error ->
      {:error, ["invalid YAML: #{Exception.message(error)}"]}
  end

  defp validate(raw) when is_map(raw) do
    version = fetch(raw, "version")
    pipeline = fetch(raw, "pipeline")

    errors = []
    errors = maybe_add_type_error(errors, version, "version", &is_integer/1, "must be an integer")
    errors = maybe_add_type_error(errors, pipeline, "pipeline", &is_map/1, "must be a map")

    if errors != [] do
      {:error, errors}
    else
      build_pipeline(version, pipeline)
    end
  end

  defp validate(_), do: {:error, ["root must be a map"]}

  defp build_pipeline(version, pipeline) do
    name = fetch(pipeline, "name")
    description = fetch(pipeline, "description")
    deploy_targets_raw = fetch(pipeline, "deploy_targets")
    stages_raw = fetch(pipeline, "stages")

    errors = []
    errors = maybe_add_type_error(errors, name, "pipeline.name", &is_binary/1, "must be a string")
    errors = maybe_add_optional_string_error(errors, description, "pipeline.description")

    {deploy_targets, errors} = build_deploy_targets(deploy_targets_raw, errors)
    deploy_target_ids = MapSet.new(deploy_targets, & &1.id)
    {stages, errors} = build_stages(stages_raw, deploy_target_ids, errors)

    errors =
      if Enum.any?(stages, &(&1.id == "warm-pool")) do
        errors
      else
        errors ++ ["pipeline.stages must include a stage with id 'warm-pool'"]
      end

    if errors == [] do
      {:ok,
       PipelineConfig.new(%{
         version: version,
         name: name,
         description: if(is_binary(description), do: description, else: nil),
         stages: stages,
         deploy_targets: deploy_targets
       })}
    else
      {:error, errors}
    end
  end

  defp build_deploy_targets(raw, errors) when is_list(raw) and raw != [] do
    Enum.with_index(raw)
    |> Enum.reduce({[], errors}, fn {item, index}, {targets, acc_errors} ->
      case build_deploy_target(item, "pipeline.deploy_targets[#{index}]") do
        {:ok, target} -> {[target | targets], acc_errors}
        {:error, item_errors} -> {targets, acc_errors ++ item_errors}
      end
    end)
    |> then(fn {targets, acc_errors} -> {Enum.reverse(targets), acc_errors} end)
  end

  defp build_deploy_targets(_, errors),
    do: {[], errors ++ ["pipeline.deploy_targets must be a non-empty list"]}

  defp build_stages(raw, deploy_target_ids, errors) when is_list(raw) and raw != [] do
    Enum.with_index(raw)
    |> Enum.reduce({[], errors}, fn {item, index}, {stages, acc_errors} ->
      case build_stage(item, "pipeline.stages[#{index}]", deploy_target_ids) do
        {:ok, stage} -> {[stage | stages], acc_errors}
        {:error, item_errors} -> {stages, acc_errors ++ item_errors}
      end
    end)
    |> then(fn {stages, acc_errors} -> {Enum.reverse(stages), acc_errors} end)
  end

  defp build_stages(_, _deploy_target_ids, errors),
    do: {[], errors ++ ["pipeline.stages must be a non-empty list"]}

  defp build_steps(raw, stage_path, errors) when is_list(raw) and raw != [] do
    Enum.with_index(raw)
    |> Enum.reduce({[], errors}, fn {item, index}, {steps, acc_errors} ->
      case build_step(item, "#{stage_path}.steps[#{index}]") do
        {:ok, step} -> {[step | steps], acc_errors}
        {:error, item_errors} -> {steps, acc_errors ++ item_errors}
      end
    end)
    |> then(fn {steps, acc_errors} -> {Enum.reverse(steps), acc_errors} end)
  end

  defp build_steps(_, stage_path, errors),
    do: {[], errors ++ ["#{stage_path}.steps must be a non-empty list"]}

  defp build_gates(nil, _stage_path, errors), do: {[], errors}

  defp build_gates(raw, stage_path, errors) when is_list(raw) do
    Enum.with_index(raw)
    |> Enum.reduce({[], errors}, fn {item, index}, {gates, acc_errors} ->
      case build_gate(item, "#{stage_path}.gates[#{index}]") do
        {:ok, gate} -> {[gate | gates], acc_errors}
        {:error, item_errors} -> {gates, acc_errors ++ item_errors}
      end
    end)
    |> then(fn {gates, acc_errors} -> {Enum.reverse(gates), acc_errors} end)
  end

  defp build_gates(_, stage_path, errors),
    do: {[], errors ++ ["#{stage_path}.gates must be a list"]}

  defp build_deploy_target(item, path) when is_map(item) do
    id = fetch(item, "id")
    environment = fetch(item, "environment")
    provider = fetch(item, "provider")
    strategy = fetch(item, "strategy") || "rolling"
    region = fetch(item, "region")

    errors = []
    errors = maybe_add_type_error(errors, id, "#{path}.id", &is_binary/1, "must be a string")

    errors =
      maybe_add_type_error(
        errors,
        environment,
        "#{path}.environment",
        &is_binary/1,
        "must be a string"
      )

    errors =
      maybe_add_type_error(errors, provider, "#{path}.provider", &is_binary/1, "must be a string")

    errors =
      maybe_add_type_error(errors, strategy, "#{path}.strategy", &is_binary/1, "must be a string")

    errors = maybe_add_optional_string_error(errors, region, "#{path}.region")

    build_result(errors, fn ->
      DeployTarget.new(%{
        id: id,
        environment: environment,
        provider: provider,
        strategy: strategy,
        region: region,
        config: Map.drop(item, ["id", "environment", "provider", "strategy", "region"])
      })
    end)
  end

  defp build_deploy_target(_, path), do: {:error, ["#{path} must be a map"]}

  defp build_stage(item, path, deploy_target_ids) when is_map(item) do
    id = fetch(item, "id")
    type = fetch(item, "type")
    deploy_target = fetch(item, "deploy_target")

    errors = []
    errors = maybe_add_type_error(errors, id, "#{path}.id", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, type, "#{path}.type", &is_binary/1, "must be a string")
    errors = maybe_add_optional_string_error(errors, deploy_target, "#{path}.deploy_target")

    errors =
      maybe_add_deploy_target_reference_error(errors, deploy_target, deploy_target_ids, path)

    {steps, errors} = build_steps(fetch(item, "steps"), path, errors)
    {gates, errors} = build_gates(fetch(item, "gates"), path, errors)

    build_result(errors, fn ->
      Stage.new(%{
        id: id,
        type: type,
        deploy_target: deploy_target,
        steps: steps,
        gates: gates
      })
    end)
  end

  defp build_stage(_, path, _deploy_target_ids), do: {:error, ["#{path} must be a map"]}

  defp build_step(item, path) when is_map(item) do
    name = fetch(item, "name")
    run = fetch(item, "run")
    timeout_seconds = fetch(item, "timeout_seconds")
    retries = fetch(item, "retries") || 0
    env = fetch(item, "env") || %{}

    errors = []
    errors = maybe_add_type_error(errors, name, "#{path}.name", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, run, "#{path}.run", &is_binary/1, "must be a string")
    errors = maybe_add_timeout_error(errors, timeout_seconds, "#{path}.timeout_seconds")
    errors = maybe_add_retries_error(errors, retries, "#{path}.retries")
    errors = maybe_add_type_error(errors, env, "#{path}.env", &is_map/1, "must be a map")

    build_result(errors, fn ->
      Step.new(%{
        name: name,
        run: run,
        timeout_seconds: timeout_seconds,
        retries: retries,
        env: env
      })
    end)
  end

  defp build_step(_, path), do: {:error, ["#{path} must be a map"]}

  defp build_gate(item, path) when is_map(item) do
    type = fetch(item, "type")
    required = fetch(item, "required")
    required = if is_nil(required), do: true, else: required

    errors = []
    errors = maybe_add_type_error(errors, type, "#{path}.type", &is_binary/1, "must be a string")
    errors = maybe_add_boolean_error(errors, required, "#{path}.required")

    build_result(errors, fn ->
      params = Map.drop(item, ["type", "required"])
      Gate.new(%{type: type, required: required, params: params})
    end)
  end

  defp build_gate(_, path), do: {:error, ["#{path} must be a map"]}

  defp build_result([], builder), do: {:ok, builder.()}
  defp build_result(errors, _builder), do: {:error, errors}

  defp maybe_add_deploy_target_reference_error(errors, deploy_target, deploy_target_ids, path) do
    if is_nil(deploy_target) or MapSet.member?(deploy_target_ids, deploy_target) do
      errors
    else
      errors ++ ["#{path}.deploy_target must reference a declared deploy target"]
    end
  end

  defp maybe_add_type_error(errors, value, path, predicate, message) do
    if predicate.(value), do: errors, else: errors ++ ["#{path} #{message}"]
  end

  defp maybe_add_optional_string_error(errors, value, path) do
    if is_nil(value) or is_binary(value) do
      errors
    else
      errors ++ ["#{path} must be a string when present"]
    end
  end

  defp maybe_add_boolean_error(errors, value, path) do
    if is_boolean(value), do: errors, else: errors ++ ["#{path} must be a boolean"]
  end

  defp maybe_add_timeout_error(errors, value, path) do
    if is_nil(value) or (is_integer(value) and value > 0) do
      errors
    else
      errors ++ ["#{path} must be a positive integer when present"]
    end
  end

  defp maybe_add_retries_error(errors, value, path) do
    if is_integer(value) and value >= 0 do
      errors
    else
      errors ++ ["#{path} must be a non-negative integer"]
    end
  end

  defp fetch(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> fetch_atom_key(map, key)
    end
  end

  defp fetch_atom_key(map, key) do
    Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError ->
      Map.get(map, key)
  end
end
