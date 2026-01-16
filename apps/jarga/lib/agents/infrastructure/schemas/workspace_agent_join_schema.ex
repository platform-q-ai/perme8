defmodule Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema do
  @moduledoc """
  Ecto schema for the many-to-many relationship between agents and workspaces.

  This schema represents which agents are available in which workspaces.
  An agent can be added to multiple workspaces, and a workspace can have multiple agents.

  Located in infrastructure layer as it's an Ecto-specific implementation detail.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Jarga.Agents.Infrastructure.Schemas.AgentSchema
  alias Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          workspace_id: Ecto.UUID.t(),
          agent_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "workspace_agents" do
    belongs_to(:workspace, WorkspaceSchema)
    belongs_to(:agent, AgentSchema)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for workspace_agent join record.

  ## Required Fields
  - workspace_id
  - agent_id
  """
  def changeset(workspace_agent_join, attrs) do
    workspace_agent_join
    |> cast(attrs, [:workspace_id, :agent_id])
    |> validate_required([:workspace_id, :agent_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:agent_id)
    |> unique_constraint([:workspace_id, :agent_id],
      name: :workspace_agents_workspace_id_agent_id_index,
      message: "has already been taken"
    )
  end
end
