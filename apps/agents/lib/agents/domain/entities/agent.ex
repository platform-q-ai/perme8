defmodule Agents.Domain.Entities.Agent do
  @moduledoc """
  Pure domain entity for AI agents.

  This is a value object representing an agent in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Agents.Infrastructure.Schemas.AgentSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          system_prompt: String.t() | nil,
          model: String.t() | nil,
          temperature: float(),
          input_token_cost: Decimal.t() | nil,
          cached_input_token_cost: Decimal.t() | nil,
          output_token_cost: Decimal.t() | nil,
          cached_output_token_cost: Decimal.t() | nil,
          visibility: String.t(),
          enabled: boolean(),
          user_id: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :description,
    :system_prompt,
    :model,
    :input_token_cost,
    :cached_input_token_cost,
    :output_token_cost,
    :cached_output_token_cost,
    :user_id,
    :inserted_at,
    :updated_at,
    temperature: 0.7,
    visibility: "PRIVATE",
    enabled: true
  ]

  @doc """
  Creates a new Agent domain entity from attributes.

  ## Examples

      iex> new(%{user_id: "user-123", name: "Test Agent"})
      %Agent{user_id: "user-123", name: "Test Agent", visibility: "PRIVATE"}
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.

  ## Examples

      iex> from_schema(%AgentSchema{...})
      %Agent{...}
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      system_prompt: schema.system_prompt,
      model: schema.model,
      temperature: schema.temperature,
      input_token_cost: schema.input_token_cost,
      cached_input_token_cost: schema.cached_input_token_cost,
      output_token_cost: schema.output_token_cost,
      cached_output_token_cost: schema.cached_output_token_cost,
      visibility: schema.visibility,
      enabled: schema.enabled,
      user_id: schema.user_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Returns list of valid visibility values.
  """
  def valid_visibilities do
    ["PRIVATE", "SHARED"]
  end
end
