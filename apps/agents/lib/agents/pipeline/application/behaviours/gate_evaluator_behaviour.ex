defmodule Agents.Pipeline.Application.Behaviours.GateEvaluatorBehaviour do
  @moduledoc false

  alias Agents.Pipeline.Domain.Entities.{Gate, GateResult, Stage}

  @callback evaluate(Stage.t(), [Gate.t()], map()) ::
              {:ok,
               %{
                 status: :passed | :blocked | :failed,
                 gate_results: [GateResult.t()],
                 metadata: map(),
                 reason: term() | nil
               }}
end
