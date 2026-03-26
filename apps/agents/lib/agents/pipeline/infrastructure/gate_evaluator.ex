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
end
