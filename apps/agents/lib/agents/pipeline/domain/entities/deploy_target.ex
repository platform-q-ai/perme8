defmodule Agents.Pipeline.Domain.Entities.DeployTarget do
  @moduledoc """
  Pure domain entity representing a deployment target configuration.

  Supports different deployment types (render, k3s) with target-specific config.
  No infrastructure dependencies.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: String.t() | nil,
          auto_deploy: boolean(),
          config: map()
        }

  defstruct name: nil,
            type: nil,
            auto_deploy: false,
            config: %{}

  @doc "Creates a new DeployTarget from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Returns true if this is a Render.com deployment target."
  @spec render?(t()) :: boolean()
  def render?(%__MODULE__{type: "render"}), do: true
  def render?(%__MODULE__{}), do: false

  @doc "Returns the auto_deploy flag."
  @spec auto_deploy?(t()) :: boolean()
  def auto_deploy?(%__MODULE__{auto_deploy: auto_deploy}), do: auto_deploy
end
