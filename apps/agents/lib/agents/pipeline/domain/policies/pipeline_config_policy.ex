defmodule Agents.Pipeline.Domain.Policies.PipelineConfigPolicy do
  @moduledoc """
  Pure business rules for validating pipeline configuration.

  Validates a `PipelineConfig` entity for structural correctness: version,
  stage names, trigger events, step names, gate references, and deploy target types.
  No I/O, no Repo, no Ecto.
  """

  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Gate}

  @supported_versions [1]
  @valid_trigger_events ~w(on_session_complete on_pull_request on_merge schedule on_demand manual)
  @valid_evaluation_strategies ~w(all_of any_of)
  @valid_deploy_target_types ~w(render k3s)

  @doc "Validates a PipelineConfig entity. Returns `:ok` or `{:error, reason}`."
  @spec validate(PipelineConfig.t()) :: :ok | {:error, term()}
  def validate(%PipelineConfig{} = config) do
    with :ok <- validate_version(config),
         :ok <- validate_stages_present(config),
         :ok <- validate_stage_names(config),
         :ok <- validate_triggers(config),
         :ok <- validate_steps(config),
         :ok <- validate_gates(config),
         :ok <- validate_deploy_targets(config) do
      :ok
    end
  end

  @doc "Returns the list of valid trigger event strings."
  @spec valid_trigger_events() :: [String.t()]
  def valid_trigger_events, do: @valid_trigger_events

  @doc "Returns the list of valid evaluation strategy strings."
  @spec valid_evaluation_strategies() :: [String.t()]
  def valid_evaluation_strategies, do: @valid_evaluation_strategies

  @doc "Returns the list of valid deploy target type strings."
  @spec valid_deploy_target_types() :: [String.t()]
  def valid_deploy_target_types, do: @valid_deploy_target_types

  @doc "Returns true if the given value is a valid, non-empty stage name string."
  @spec valid_stage_name?(term()) :: boolean()
  def valid_stage_name?(name) when is_binary(name) and name != "", do: true
  def valid_stage_name?(_), do: false

  # Private validation steps

  defp validate_version(%PipelineConfig{version: nil}), do: {:error, :missing_version}

  defp validate_version(%PipelineConfig{version: v}) when v in @supported_versions, do: :ok

  defp validate_version(%PipelineConfig{version: v}), do: {:error, {:unsupported_version, v}}

  defp validate_stages_present(%PipelineConfig{stages: []}), do: {:error, :no_stages}
  defp validate_stages_present(%PipelineConfig{}), do: :ok

  defp validate_stage_names(%PipelineConfig{stages: stages}) do
    with :ok <- check_stage_names_present(stages) do
      check_stage_names_unique(stages)
    end
  end

  defp check_stage_names_present(stages) do
    missing =
      stages
      |> Enum.with_index()
      |> Enum.filter(fn {stage, _idx} -> not valid_stage_name?(stage.name) end)
      |> Enum.map(fn {_stage, idx} -> idx end)

    case missing do
      [] -> :ok
      indexes -> {:error, {:stages_missing_names, indexes}}
    end
  end

  defp check_stage_names_unique(stages) do
    names = Enum.map(stages, & &1.name)

    duplicates =
      names
      |> Enum.frequencies()
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> name end)

    case duplicates do
      [] -> :ok
      dups -> {:error, {:duplicate_stage_names, dups}}
    end
  end

  defp validate_triggers(%PipelineConfig{stages: stages}) do
    Enum.reduce_while(stages, :ok, fn stage, :ok ->
      case validate_stage_triggers(stage) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_stage_triggers(%Stage{trigger: %{events: events}, name: name})
       when is_list(events) do
    case Enum.find(events, fn e -> e not in @valid_trigger_events end) do
      nil -> :ok
      invalid -> {:error, {:invalid_trigger_event, name, invalid}}
    end
  end

  defp validate_stage_triggers(%Stage{}), do: :ok

  defp validate_steps(%PipelineConfig{stages: stages}) do
    Enum.reduce_while(stages, :ok, fn stage, :ok ->
      case validate_stage_steps(stage) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_stage_steps(%Stage{steps: steps, name: stage_name}) do
    steps
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {step, idx}, :ok ->
      if valid_stage_name?(step.name) do
        {:cont, :ok}
      else
        {:halt, {:error, {:step_missing_name, stage_name, idx}}}
      end
    end)
  end

  defp validate_gates(%PipelineConfig{stages: stages}) do
    stage_names = MapSet.new(stages, & &1.name)

    Enum.reduce_while(stages, :ok, fn stage, :ok ->
      case validate_stage_gate(stage, stage_names) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_stage_gate(%Stage{gate: nil}, _stage_names), do: :ok

  defp validate_stage_gate(%Stage{gate: gate, name: stage_name}, stage_names) do
    with :ok <- validate_gate_evaluation(gate, stage_name) do
      validate_gate_dependencies(gate, stage_name, stage_names)
    end
  end

  defp validate_gate_evaluation(%Gate{evaluation: eval}, stage_name) do
    if eval in @valid_evaluation_strategies do
      :ok
    else
      {:error, {:invalid_gate_evaluation, stage_name, eval}}
    end
  end

  defp validate_gate_dependencies(%Gate{} = gate, stage_name, stage_names) do
    case Enum.find(Gate.dependency_names(gate), fn dep -> dep not in stage_names end) do
      nil -> :ok
      unknown -> {:error, {:gate_references_unknown_stage, stage_name, unknown}}
    end
  end

  defp validate_deploy_targets(%PipelineConfig{deploy_targets: targets}) do
    Enum.reduce_while(targets, :ok, fn target, :ok ->
      if target.type in @valid_deploy_target_types do
        {:cont, :ok}
      else
        {:halt, {:error, {:invalid_deploy_target_type, target.name, target.type}}}
      end
    end)
  end
end
