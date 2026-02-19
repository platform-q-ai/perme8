defmodule AgentsApi.AgentApiController do
  @moduledoc """
  Controller for Agent CRUD API endpoints.

  Handles REST API requests for agent management using API key authentication.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were accessing the data directly.

  ## Endpoints

    * `GET /api/agents` - List agents owned by the authenticated user
    * `GET /api/agents/:id` - Get agent details
    * `POST /api/agents` - Create a new agent
    * `PATCH /api/agents/:id` - Update an agent
    * `DELETE /api/agents/:id` - Delete an agent

  """

  use AgentsApi, :controller

  @allowed_create_fields ~w(name description system_prompt model temperature visibility enabled)
  @allowed_update_fields ~w(name description system_prompt model temperature visibility enabled)

  @doc """
  Lists all agents owned by the authenticated user.
  """
  def index(conn, _params) do
    user = conn.assigns.current_user
    agents = Agents.list_user_agents(user.id)
    render(conn, :index, agents: agents)
  end

  @doc """
  Gets a single agent by ID.

  Returns 404 if the agent doesn't exist or belongs to another user.
  """
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Agents.get_user_agent(id, user.id) do
      {:ok, agent} ->
        render(conn, :show, agent: agent)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Agent not found")
    end
  end

  @doc """
  Creates a new agent owned by the authenticated user.
  """
  def create(conn, params) do
    user = conn.assigns.current_user

    attrs =
      params
      |> Map.take(@allowed_create_fields)
      |> Map.put("user_id", user.id)

    case Agents.create_user_agent(attrs) do
      {:ok, agent} ->
        conn
        |> put_status(:created)
        |> render(:created, agent: agent)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)
    end
  end

  @doc """
  Updates an agent owned by the authenticated user.
  """
  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    attrs = Map.take(params, @allowed_update_fields)

    case Agents.update_user_agent(id, user.id, attrs) do
      {:ok, agent} ->
        render(conn, :show, agent: agent)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Agent not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)
    end
  end

  @doc """
  Deletes an agent owned by the authenticated user.
  """
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Agents.delete_user_agent(id, user.id) do
      {:ok, agent} ->
        render(conn, :show, agent: agent)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Agent not found")
    end
  end
end
