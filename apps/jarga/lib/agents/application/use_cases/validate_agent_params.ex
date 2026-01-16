defmodule Jarga.Agents.Application.UseCases.ValidateAgentParams do
  @moduledoc """
  Use case for validating agent parameters without persisting.

  Useful for form validation to provide real-time feedback to users.
  """

  alias Jarga.Agents.Domain.Entities.Agent

  @doc """
  Validates agent parameters.

  ## Parameters
  - `attrs` - Map of agent attributes to validate

  ## Returns
  - `%Ecto.Changeset{}` - Changeset with validation results
  """
  def execute(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Map.put(:action, :validate)
  end
end
