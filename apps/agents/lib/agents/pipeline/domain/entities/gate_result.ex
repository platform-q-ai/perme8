defmodule Agents.Pipeline.Domain.Entities.GateResult do
  @moduledoc "Value object describing a single gate evaluation outcome."

  @type status :: :passed | :blocked | :failed

  @type t :: %__MODULE__{
          gate_type: String.t(),
          status: status(),
          required: boolean(),
          reason: String.t() | nil,
          metadata: map()
        }

  defstruct [:gate_type, :status, :required, :reason, metadata: %{}]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{
      "gate_type" => result.gate_type,
      "status" => Atom.to_string(result.status),
      "required" => result.required,
      "reason" => result.reason,
      "metadata" => result.metadata || %{}
    }
  end
end
