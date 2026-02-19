defmodule AgentsApi.SkillApiController do
  @moduledoc """
  Controller for Skills API endpoints.

  Lists the MCP tools/skills available to an agent. Currently read-only
  and returns the system-level skill configuration.

  ## Endpoints

    * `GET /api/agents/:id/skills` - List available skills for an agent

  """

  use AgentsApi, :controller

  # System-level skills available to all agents (v1: static list)
  @available_skills [
    %{
      name: "knowledge.create",
      description: "Create a new knowledge entry in the workspace knowledge base"
    },
    %{
      name: "knowledge.update",
      description: "Update an existing knowledge entry"
    },
    %{
      name: "knowledge.get",
      description: "Get a knowledge entry with its relationships"
    },
    %{
      name: "knowledge.search",
      description: "Search knowledge entries by keyword, tags, and/or category"
    },
    %{
      name: "knowledge.traverse",
      description: "Traverse the knowledge graph from a starting entry"
    },
    %{
      name: "knowledge.relate",
      description: "Create a relationship between two knowledge entries"
    },
    %{
      name: "jarga.list_workspaces",
      description: "List workspaces accessible to the user"
    },
    %{
      name: "jarga.get_workspace",
      description: "Get workspace details by slug"
    },
    %{
      name: "jarga.list_projects",
      description: "List projects in a workspace"
    },
    %{
      name: "jarga.create_project",
      description: "Create a project in a workspace"
    },
    %{
      name: "jarga.get_project",
      description: "Get project details by slug"
    },
    %{
      name: "jarga.list_documents",
      description: "List documents in a workspace"
    },
    %{
      name: "jarga.create_document",
      description: "Create a document in a workspace"
    },
    %{
      name: "jarga.get_document",
      description: "Get document details by slug"
    }
  ]

  @doc """
  Lists skills available to an agent.

  Returns all system-level MCP tools that the agent can use.
  """
  def index(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Agents.get_user_agent(id, user.id) do
      {:ok, _agent} ->
        skills = Enum.map(@available_skills, &struct_skill/1)
        render(conn, :index, skills: skills)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Agent not found")
    end
  end

  defp struct_skill(skill_map) do
    %{name: skill_map.name, description: skill_map.description}
  end
end
