defmodule Agents.Pipeline.Application.PipelineConfigBuilder do
  @moduledoc false

  alias Agents.Pipeline.Domain.Entities.{Gate, PipelineConfig, Stage, Step}

  @spec build(map()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def build(raw) when is_map(raw) do
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

  def build(_), do: {:error, ["root must be a map"]}

  defp build_pipeline(version, pipeline) do
    name = fetch(pipeline, "name")
    description = fetch(pipeline, "description")
    stages_raw = fetch(pipeline, "stages")
    merge_queue_raw = fetch(pipeline, "merge_queue") || %{}

    errors = []
    errors = maybe_add_type_error(errors, name, "pipeline.name", &is_binary/1, "must be a string")
    errors = maybe_add_optional_string_error(errors, description, "pipeline.description")

    {stages, errors} = build_stages(stages_raw, errors)
    {merge_queue, errors} = build_merge_queue(merge_queue_raw, errors)
    errors = errors ++ flow_errors(stages)

    if errors == [] do
      {:ok,
       PipelineConfig.new(%{
         version: version,
         name: name,
         description: if(is_binary(description), do: description, else: nil),
         stages: stages,
         merge_queue: merge_queue
       })}
    else
      {:error, errors}
    end
  end

  defp build_stages(raw, errors) when is_list(raw) and raw != [] do
    Enum.with_index(raw)
    |> Enum.reduce({[], errors}, fn {item, index}, {stages, acc_errors} ->
      case build_stage(item, "pipeline.stages[#{index}]", index, raw) do
        {:ok, stage} -> {[stage | stages], acc_errors}
        {:error, item_errors} -> {stages, acc_errors ++ item_errors}
      end
    end)
    |> then(fn {stages, acc_errors} -> {Enum.reverse(stages), acc_errors} end)
  end

  defp build_stages(_, errors),
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

  defp build_stage(item, path, index, stages_raw) when is_map(item) do
    id = fetch(item, "id")
    type = fetch(item, "type")
    schedule = fetch(item, "schedule")
    triggers = fetch(item, "triggers")
    depends_on = default_stage_dependencies(index, stages_raw, fetch(item, "depends_on"))
    ticket_concurrency = fetch(item, "ticket_concurrency")

    stage_config =
      Map.drop(item, [
        "id",
        "type",
        "schedule",
        "triggers",
        "depends_on",
        "ticket_concurrency",
        "steps",
        "gates"
      ])

    errors = []
    errors = maybe_add_type_error(errors, id, "#{path}.id", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, type, "#{path}.type", &is_binary/1, "must be a string")
    errors = maybe_add_optional_map_error(errors, schedule, "#{path}.schedule")
    errors = maybe_add_string_list_error(errors, triggers || [], "#{path}.triggers")
    errors = maybe_add_string_list_error(errors, depends_on, "#{path}.depends_on")

    errors =
      maybe_add_optional_non_neg_integer_error(
        errors,
        ticket_concurrency,
        "#{path}.ticket_concurrency"
      )

    {steps, errors} = build_steps(fetch(item, "steps"), path, errors)
    {gates, errors} = build_gates(fetch(item, "gates"), path, errors)

    build_result(errors, fn ->
      Stage.new(%{
        id: id,
        type: type,
        schedule: schedule,
        triggers: triggers || [],
        depends_on: depends_on,
        ticket_concurrency: ticket_concurrency,
        config: stage_config,
        steps: steps,
        gates: gates
      })
    end)
  end

  defp build_stage(_, path, _index, _stages_raw), do: {:error, ["#{path} must be a map"]}

  defp build_step(item, path) when is_map(item) do
    name = fetch(item, "name")
    run = fetch(item, "run")
    timeout_seconds = fetch(item, "timeout_seconds")
    retries = fetch(item, "retries") || 0
    env = fetch(item, "env") || %{}
    conditions = fetch(item, "conditions")
    depends_on = fetch(item, "depends_on") || []

    errors = []
    errors = maybe_add_type_error(errors, name, "#{path}.name", &is_binary/1, "must be a string")
    errors = maybe_add_type_error(errors, run, "#{path}.run", &is_binary/1, "must be a string")
    errors = maybe_add_timeout_error(errors, timeout_seconds, "#{path}.timeout_seconds")
    errors = maybe_add_retries_error(errors, retries, "#{path}.retries")
    errors = maybe_add_type_error(errors, env, "#{path}.env", &is_map/1, "must be a map")
    errors = maybe_add_optional_string_error(errors, conditions, "#{path}.conditions")
    errors = maybe_add_string_list_error(errors, depends_on, "#{path}.depends_on")

    build_result(errors, fn ->
      Step.new(%{
        name: name,
        run: run,
        timeout_seconds: timeout_seconds,
        retries: retries,
        env: env,
        conditions: conditions,
        depends_on: depends_on
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

  defp maybe_add_optional_non_neg_integer_error(errors, value, path) do
    if is_nil(value) or (is_integer(value) and value >= 0) do
      errors
    else
      errors ++ ["#{path} must be a non-negative integer when present"]
    end
  end

  defp default_stage_dependencies(0, _stages_raw, nil), do: []

  defp default_stage_dependencies(_index, _stages_raw, depends_on) when is_list(depends_on),
    do: depends_on

  defp default_stage_dependencies(index, stages_raw, nil) do
    previous_stage = Enum.at(stages_raw, index - 1) || %{}
    previous_id = fetch(previous_stage, "id")
    if is_binary(previous_id), do: [previous_id], else: []
  end

  defp flow_errors(stages) do
    root_stages = Enum.filter(stages, &(Enum.empty?(&1.depends_on) and &1.triggers != []))

    root_count_error =
      if root_stages == [],
        do: ["pipeline must define at least one entry stage with triggers"],
        else: []

    unknown_dependency_errors = dependency_errors(stages)
    root_count_error ++ unknown_dependency_errors
  end

  defp dependency_errors(stages) do
    stage_ids = MapSet.new(stages, & &1.id)

    Enum.flat_map(stages, fn stage ->
      Enum.flat_map(stage.depends_on, fn dependency ->
        if MapSet.member?(stage_ids, dependency) do
          []
        else
          ["pipeline stage #{stage.id} depends_on unknown stage #{dependency}"]
        end
      end)
    end)
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
