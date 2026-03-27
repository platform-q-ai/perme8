defmodule Agents.Pipeline.Infrastructure.GateEvaluator do
  @moduledoc "Evaluates stage gates as first-class progression checks."

  @behaviour Agents.Pipeline.Application.Behaviours.GateEvaluatorBehaviour

  alias Agents.Pipeline.Domain.Entities.{Gate, GateResult, Stage}

  @impl true
  def evaluate(%Stage{} = stage, gates, context) when is_list(gates) do
    gate_results = Enum.map(gates, &evaluate_gate(stage, &1, context))

    cond do
      Enum.any?(gate_results, &(&1.status == :failed and &1.required)) ->
        {:ok, summary(stage, gate_results, :failed)}

      Enum.any?(gate_results, &(&1.status == :blocked and &1.required)) ->
        {:ok, summary(stage, gate_results, :blocked)}

      true ->
        {:ok, summary(stage, gate_results, :passed)}
    end
  end

  defp evaluate_gate(_stage, %Gate{type: "quality", required: required, params: params}, context) do
    checks = Map.get(params || %{}, "checks", [])
    executed_steps = context |> Map.get("stage_execution", %{}) |> Map.get("steps", [])
    executed_step_names = Enum.map(executed_steps, &Map.get(&1, "name"))

    missing_checks = Enum.reject(checks, &(&1 in executed_step_names))

    if missing_checks == [] do
      GateResult.new(%{
        gate_type: "quality",
        status: :passed,
        required: required,
        metadata: %{"checks" => checks}
      })
    else
      GateResult.new(%{
        gate_type: "quality",
        status: :failed,
        required: required,
        reason: "missing_checks",
        metadata: %{"checks" => checks, "missing_checks" => missing_checks}
      })
    end
  end

  defp evaluate_gate(
         stage,
         %Gate{type: "manual_approval", required: required, params: params},
         context
       ) do
    gate_key = Map.get(params || %{}, "key", "#{stage.id}:manual_approval")
    approved_gates = Map.get(context, "approved_gates", [])

    if gate_key in approved_gates do
      GateResult.new(%{
        gate_type: "manual_approval",
        status: :passed,
        required: required,
        metadata: %{"key" => gate_key}
      })
    else
      GateResult.new(%{
        gate_type: "manual_approval",
        status: :blocked,
        required: required,
        reason: "approval_required",
        metadata: %{"key" => gate_key}
      })
    end
  end

  defp evaluate_gate(
         _stage,
         %Gate{type: "time_window", required: required, params: params},
         context
       ) do
    current_time = Map.get(context, "current_time", DateTime.utc_now())
    after_time = Map.get(params || %{}, "after")
    before_time = Map.get(params || %{}, "before")

    allowed? = within_time_window?(current_time, after_time, before_time)

    GateResult.new(%{
      gate_type: "time_window",
      status: if(allowed?, do: :passed, else: :blocked),
      required: required,
      reason: if(allowed?, do: nil, else: "outside_time_window"),
      metadata: %{"after" => after_time, "before" => before_time}
    })
  end

  defp evaluate_gate(
         _stage,
         %Gate{type: "environment_ready", required: required, params: params},
         context
       ) do
    env_key = Map.get(params || %{}, "key", "default")
    ready_envs = Map.get(context, "ready_environments", [])

    GateResult.new(%{
      gate_type: "environment_ready",
      status: if(env_key in ready_envs, do: :passed, else: :blocked),
      required: required,
      reason: if(env_key in ready_envs, do: nil, else: "environment_not_ready"),
      metadata: %{"key" => env_key}
    })
  end

  defp evaluate_gate(_stage, %Gate{type: type, required: required, params: params}, _context) do
    GateResult.new(%{
      gate_type: type,
      status: if(required, do: :blocked, else: :passed),
      required: required,
      reason: if(required, do: "unsupported_gate", else: nil),
      metadata: params || %{}
    })
  end

  defp summary(stage, gate_results, status) do
    %{
      status: status,
      gate_results: gate_results,
      metadata: %{
        "stage_id" => stage.id,
        "gate_results" => Enum.map(gate_results, &GateResult.to_map/1)
      },
      reason: gate_results |> Enum.find(&(&1.status == status)) |> then(&(&1 && &1.reason))
    }
  end

  defp within_time_window?(%DateTime{}, nil, nil), do: true

  defp within_time_window?(%DateTime{} = current_time, after_time, before_time) do
    time = Time.truncate(DateTime.to_time(current_time), :second)
    after_ok? = is_nil(after_time) or compare_time(time, after_time) != :lt
    before_ok? = is_nil(before_time) or compare_time(time, before_time) != :gt
    after_ok? and before_ok?
  end

  defp compare_time(%Time{} = left, value) when is_binary(value) do
    case Time.from_iso8601(value <> ":00") do
      {:ok, right} -> Time.compare(left, right)
      _ -> :lt
    end
  end
end
