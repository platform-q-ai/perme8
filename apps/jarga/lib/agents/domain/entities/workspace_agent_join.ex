defmodule Jarga.Agents.Domain.Entities.WorkspaceAgentJoin do
  @moduledoc """
  Pure domain entity representing the relationship between agents and workspaces.

  This is a pure Elixir struct with no infrastructure dependencies (no Ecto).
  For database operations, use Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema.
  """

  alias Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema

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
  Creates a changeset for workspace_agent join record.
  Delegates to WorkspaceAgentJoinSchema for Ecto operations.
  """
  defdelegate changeset(workspace_agent_join, attrs), to: WorkspaceAgentJoinSchema

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
  Converts an Ecto schema to a domain entity.

  ## Examples

      iex> from_schema(%WorkspaceAgentJoinSchema{...})
      %WorkspaceAgentJoin{...}
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      workspace_id: schema.workspace_id,
      agent_id: schema.agent_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
