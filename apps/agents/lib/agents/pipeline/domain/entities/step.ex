defmodule Agents.Pipeline.Domain.Entities.Step do
  @moduledoc """
  Pure domain entity representing an individual step within a pipeline stage.

  A step is the most granular unit of execution — a named command or action.
  No infrastructure dependencies.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: String.t(),
          command: String.t() | nil,
          commands: [String.t()],
          image: String.t() | nil,
          env: map(),
          when_condition: String.t() | nil
        }

  defstruct name: nil,
            type: "command",
            command: nil,
            commands: [],
            image: nil,
            env: %{},
            when_condition: nil

  @doc "Creates a new Step from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc """
  Returns the commands for this step as a list.

  If `commands` is set (non-empty), returns it.
  If only `command` is set, wraps it in a list.
  If neither is set, returns an empty list.
  """
  @spec command_or_commands(t()) :: [String.t()]
  def command_or_commands(%__MODULE__{commands: commands}) when commands != [], do: commands
  def command_or_commands(%__MODULE__{command: cmd}) when is_binary(cmd), do: [cmd]
  def command_or_commands(%__MODULE__{}), do: []

  @doc "Returns true if this step is a provisioning step (provision_container or mark_container_ready)."
  @spec provision_step?(t()) :: boolean()
  def provision_step?(%__MODULE__{type: "provision_container"}), do: true
  def provision_step?(%__MODULE__{type: "mark_container_ready"}), do: true
  def provision_step?(%__MODULE__{}), do: false
end
