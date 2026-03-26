defmodule Agents.Pipeline.Infrastructure.YamlParser do
  @moduledoc """
  Parses and validates the pipeline YAML DSL.
  """

  @behaviour Agents.Pipeline.Application.Behaviours.PipelineParserBehaviour

  alias Agents.Pipeline.Domain.Entities.{DeployTarget, Gate, PipelineConfig, Stage, Step}

  @doc "Parses a YAML pipeline document into a validated pipeline config."
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
    merge_queue_raw = fetch(pipeline, "merge_queue") || %{}

    errors = []
    errors = maybe_add_type_error(errors, name, "pipeline.name", &is_binary/1, "must be a string")
    errors = maybe_add_optional_string_error(errors, description, "pipeline.description")

    {deploy_targets, errors} = build_deploy_targets(deploy_targets_raw, errors)
    deploy_target_ids = MapSet.new(deploy_targets, & &1.id)
    {stages, errors} = build_stages(stages_raw, deploy_target_ids, errors)
    {merge_queue, errors} = build_merge_queue(merge_queue_raw, errors)

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
         deploy_targets: deploy_targets,
         merge_queue: merge_queue
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

  defp build_merge_queue(raw, errors) when raw in [%{}, nil], do: {%{}, errors}

  defp build_merge_queue(raw, errors) when is_map(raw) do
    strategy = fetch(raw, "strategy") || "disabled"
    required_stages = fetch(raw, "required_stages") || []
    required_review = Map.get(raw, "required_review", true)
    pre_merge_validation = fetch(raw, "pre_merge_validation") || %{}

    errors =
      maybe_add_type_error(
        errors,
        strategy,
        "pipeline.merge_queue.strategy",
        &is_binary/1,
        "must be a string"
      )

    errors =
      maybe_add_string_list_error(errors, required_stages, "pipeline.merge_queue.required_stages")

    errors =
      maybe_add_boolean_error(errors, required_review, "pipeline.merge_queue.required_review")

    errors =
      maybe_add_type_error(
        errors,
        pre_merge_validation,
        "pipeline.merge_queue.pre_merge_validation",
        &is_map/1,
        "must be a map"
      )

    merge_queue = %{
      "strategy" => strategy,
      "required_stages" => required_stages,
      "required_review" => required_review,
      "pre_merge_validation" => pre_merge_validation
    }

    {merge_queue, errors}
  end

  defp build_merge_queue(_, errors), do: {%{}, errors ++ ["pipeline.merge_queue must be a map"]}

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
    schedule = fetch(item, "schedule")
    stage_config = Map.drop(item, ["id", "type", "deploy_target", "steps", "gates", "schedule"])

    errors = []
    errors = maybe_add_type_error(errors, id, "#{path}.id", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, type, "#{path}.type", &is_binary/1, "must be a string")
    errors = maybe_add_optional_string_error(errors, deploy_target, "#{path}.deploy_target")
    errors = maybe_add_optional_map_error(errors, schedule, "#{path}.schedule")

    errors =
      maybe_add_deploy_target_reference_error(errors, deploy_target, deploy_target_ids, path)

    errors =
      maybe_add_warm_pool_stage_errors(errors, type, path, stage_config, schedule)

    {steps, errors} = build_steps(fetch(item, "steps"), path, errors)
    {gates, errors} = build_gates(fetch(item, "gates"), path, errors)

    build_result(errors, fn ->
      Stage.new(%{
        id: id,
        type: type,
        deploy_target: deploy_target,
        schedule: schedule,
        config: stage_config,
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
    conditions = fetch(item, "conditions")

    errors = []
    errors = maybe_add_type_error(errors, name, "#{path}.name", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, run, "#{path}.run", &is_binary/1, "must be a string")
    errors = maybe_add_timeout_error(errors, timeout_seconds, "#{path}.timeout_seconds")
    errors = maybe_add_retries_error(errors, retries, "#{path}.retries")
    errors = maybe_add_type_error(errors, env, "#{path}.env", &is_map/1, "must be a map")
    errors = maybe_add_optional_string_error(errors, conditions, "#{path}.conditions")

    build_result(errors, fn ->
      Step.new(%{
        name: name,
        run: run,
        timeout_seconds: timeout_seconds,
        retries: retries,
        env: env,
        conditions: conditions
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

  defp maybe_add_optional_map_error(errors, value, path) do
    if is_nil(value) or is_map(value) do
      errors
    else
      errors ++ ["#{path} must be a map when present"]
    end
  end

  defp maybe_add_string_list_error(errors, values, path) when is_list(values) do
    if Enum.all?(values, &is_binary/1) do
      errors
    else
      errors ++ ["#{path} must be a list of strings"]
    end
  end

  defp maybe_add_string_list_error(errors, _values, path) do
    errors ++ ["#{path} must be a list of strings"]
  end

  defp maybe_add_warm_pool_stage_errors(errors, "warm_pool", path, config, schedule) do
    errors
    |> maybe_add_type_error(
      Map.get(config, "warm_pool"),
      "#{path}.warm_pool",
      &is_map/1,
      "must be a map"
    )
    |> maybe_add_type_error(schedule, "#{path}.schedule", &is_map/1, "must be a map")
    |> maybe_add_warm_pool_config_errors(config, path)
    |> maybe_add_schedule_errors(schedule, path)
  end

  defp maybe_add_warm_pool_stage_errors(errors, _type, _path, _config, _schedule), do: errors

  defp maybe_add_warm_pool_config_errors(errors, config, path) do
    warm_pool = Map.get(config, "warm_pool") || %{}
    readiness = Map.get(warm_pool, "readiness")

    errors
    |> maybe_add_type_error(
      Map.get(warm_pool, "target_count"),
      "#{path}.warm_pool.target_count",
      &(is_integer(&1) and &1 >= 0),
      "must be a non-negative integer"
    )
    |> maybe_add_type_error(
      Map.get(warm_pool, "image"),
      "#{path}.warm_pool.image",
      &is_binary/1,
      "must be a string"
    )
    |> maybe_add_type_error(readiness, "#{path}.warm_pool.readiness", &is_map/1, "must be a map")
    |> maybe_add_type_error(
      if(is_map(readiness), do: Map.get(readiness, "strategy")),
      "#{path}.warm_pool.readiness.strategy",
      &is_binary/1,
      "must be a string"
    )
  end

  defp maybe_add_schedule_errors(errors, schedule, path) do
    maybe_add_type_error(
      errors,
      if(is_map(schedule), do: Map.get(schedule, "cron")),
      "#{path}.schedule.cron",
      &is_binary/1,
      "must be a string"
    )
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
