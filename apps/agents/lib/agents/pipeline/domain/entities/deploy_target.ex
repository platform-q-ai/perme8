defmodule Agents.Pipeline.Domain.Entities.DeployTarget do
  @moduledoc """
  Value object for a deployment destination.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          environment: String.t(),
          provider: String.t(),
          strategy: String.t(),
          region: String.t() | nil,
          config: map()
        }

  defstruct [:id, :environment, :provider, :region, strategy: "rolling", config: %{}]

  @doc "Builds a deploy target value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end
