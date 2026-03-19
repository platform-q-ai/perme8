defmodule Agents.Pipeline.Domain.Entities.Stage do
  @moduledoc """
  Pure domain entity representing a pipeline stage.

  A stage contains steps and optional gate conditions. It can be triggered
  by various events (session complete, PR, merge, schedule, etc.).
  No infrastructure dependencies.
  """

  alias Agents.Pipeline.Domain.Entities.{Step, Gate}

  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t() | nil,
          trigger: map(),
          steps: [Step.t()],
          gate: Gate.t() | nil,
          pool: map() | nil,
          failure_action: String.t(),
          timeout: integer() | nil
        }

  defstruct name: nil,
            description: nil,
            trigger: %{},
            steps: [],
            gate: nil,
            pool: nil,
            failure_action: "block",
            timeout: nil

  @doc "Creates a new Stage from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Returns true if this is the warm-pool stage."
  @spec warm_pool_stage?(t()) :: boolean()
  def warm_pool_stage?(%__MODULE__{name: "warm-pool"}), do: true
  def warm_pool_stage?(%__MODULE__{}), do: false

  @doc "Returns true if this stage responds to the given trigger event."
  @spec triggered_by?(t(), String.t()) :: boolean()
  def triggered_by?(%__MODULE__{trigger: %{events: events}}, event) when is_list(events) do
    event in events
  end

  def triggered_by?(%__MODULE__{}, _event), do: false

  @doc "Returns true if this stage has a non-nil, non-empty gate."
  @spec has_gate?(t()) :: boolean()
  def has_gate?(%__MODULE__{gate: nil}), do: false
  def has_gate?(%__MODULE__{gate: gate}), do: not Gate.empty?(gate)

  @doc "Returns the number of steps in this stage."
  @spec step_count(t()) :: non_neg_integer()
  def step_count(%__MODULE__{steps: steps}), do: length(steps)
end
