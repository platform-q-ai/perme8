defmodule Jarga.Agents.Domain.Entities.WorkspaceAgentJoin do
  @moduledoc """
  Pure domain entity representing the relationship between agents and workspaces.

  This is a pure Elixir struct with no infrastructure dependencies (no Ecto).
  For database operations, use Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t(),
          agent_id: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :agent_id,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new WorkspaceAgentJoin domain entity.

  ## Examples

      iex> new(%{workspace_id: "ws-1", agent_id: "ag-1"})
      %WorkspaceAgentJoin{workspace_id: "ws-1", agent_id: "ag-1"}
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an Ecto schema (or any map/struct with matching fields) to a domain entity.

  ## Examples

      iex> from_schema(%{id: "123", workspace_id: "ws-1", agent_id: "ag-1"})
      %WorkspaceAgentJoin{id: "123", workspace_id: "ws-1", agent_id: "ag-1"}
  """
  def from_schema(schema) do
    %__MODULE__{
      id: Map.get(schema, :id),
      workspace_id: Map.get(schema, :workspace_id),
      agent_id: Map.get(schema, :agent_id),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    }
  end
end
