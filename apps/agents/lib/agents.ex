defmodule Agents do
  @moduledoc """
  The Agents context.

  Handles AI agent management, processing, and AI-powered chat functionality.

  ## Error Types

  Standard error atoms returned by this context:

  - `:not_found` - Agent not found or user doesn't have access to it
  - `:forbidden` - User is not authorized to perform this action
  - `:invalid_params` - Validation error (returns `{:error, changeset}`)

  ## Examples

      # Success
      {:ok, agent} = Agents.create_user_agent(%{...})

      # Not found (agent doesn't exist or user lacks access)
      {:error, :not_found} = Agents.update_user_agent(agent_id, user_id, %{...})

      # Forbidden (user not authorized)
      {:error, :forbidden} = Agents.clone_shared_agent(private_agent_id, other_user_id)

      # Invalid parameters
      {:error, %Ecto.Changeset{}} = Agents.create_user_agent(%{invalid: "data"})
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Delegates to layer boundaries for Clean Architecture enforcement
  use Boundary,
    top_level?: true,
    deps: [
      Agents.Domain,
      Agents.Application,
      Agents.Infrastructure,
      Identity.Repo,
      EntityRelationshipManager
    ],
    exports: [
      {Domain.Entities.Agent, []}
    ]

  alias Agents.Infrastructure.Services.LlmClient

  alias Agents.Application.UseCases.{
    AgentQuery,
    ListUserAgents,
    CreateUserAgent,
    UpdateUserAgent,
    DeleteUserAgent,
    CloneSharedAgent,
    ListWorkspaceAvailableAgents,
    ListViewableAgents,
    ValidateAgentParams,
    SyncAgentWorkspaces
  }

  @doc """
  Sends a chat completion request to the LLM.

  ## Examples

      iex> chat([%{role: "user", content: "Hello!"}])
      {:ok, "Hello! How can I help you?"}

  """
  defdelegate chat(messages, opts \\ []), to: LlmClient

  @doc """
  Streams a chat completion response in chunks.

  ## Examples

      iex> {:ok, _pid} = chat_stream(messages, self())
      iex> receive do
      ...>   {:chunk, text} -> IO.puts(text)
      ...> end

  """
  defdelegate chat_stream(messages, caller_pid, opts \\ []), to: LlmClient

  @doc """
  Executes an AI query with document context and streams response.

  This is used for in-editor AI assistance. The AI response is streamed
  to the caller process as chunks.

  ## Parameters
    - params: Map with required keys:
      - :question - The user's question
      - :assigns - LiveView assigns containing document context
      - :node_id (optional) - Node ID for tracking in the editor
    - caller_pid: Process to receive streaming chunks

  ## Examples

      iex> params = %{
      ...>   question: "How do I structure a Phoenix context?",
      ...>   assigns: socket.assigns,
      ...>   node_id: "ai_node_123"
      ...> }
      iex> agent_query(params, self())
      {:ok, #PID<0.123.0>}

      # Then receive messages:
      receive do
        {:agent_chunk, node_id, chunk} -> IO.puts(chunk)
        {:agent_done, node_id, response} -> IO.puts("Complete!")
        {:agent_error, node_id, reason} -> IO.puts("Error: " <> reason)
      end

  """
  defdelegate agent_query(params, caller_pid), to: AgentQuery, as: :execute

  # User-scoped agent management

  @doc """
  Lists all agents owned by the user.

  ## Examples

      iex> list_user_agents(user_id)
      [%Agent{}, ...]
  """
  defdelegate list_user_agents(user_id), to: ListUserAgents, as: :execute

  @doc """
  Lists all agents viewable by the user.

  Returns user's own agents plus all shared agents (without workspace context).

  ## Examples

      iex> list_viewable_agents(user_id)
      [%Agent{}, ...]
  """
  defdelegate list_viewable_agents(user_id), to: ListViewableAgents, as: :execute

  @doc """
  Creates a new user-owned agent.

  ## Examples

      iex> create_user_agent(%{user_id: user_id, name: "My Agent"})
      {:ok, %Agent{}}
  """
  defdelegate create_user_agent(attrs), to: CreateUserAgent, as: :execute

  @doc """
  Validates agent parameters without persisting.

  Returns a changeset for form validation purposes.

  ## Examples

      iex> validate_agent_params(%{name: "My Agent", temperature: "1.5"})
      %Ecto.Changeset{valid?: true}

      iex> validate_agent_params(%{temperature: "invalid"})
      %Ecto.Changeset{valid?: false}
  """
  defdelegate validate_agent_params(attrs), to: ValidateAgentParams, as: :execute

  @doc """
  Updates an agent owned by the user.

  ## Examples

      iex> update_user_agent(agent_id, user_id, %{name: "New Name"})
      {:ok, %Agent{}}
  """
  defdelegate update_user_agent(agent_id, user_id, attrs), to: UpdateUserAgent, as: :execute

  @doc """
  Deletes an agent owned by the user.

  ## Examples

      iex> delete_user_agent(agent_id, user_id)
      {:ok, %Agent{}}
  """
  defdelegate delete_user_agent(agent_id, user_id), to: DeleteUserAgent, as: :execute

  @doc """
  Clones a shared agent to the user's personal library.

  ## Examples

      iex> clone_shared_agent(agent_id, user_id)
      {:ok, %Agent{}}

      iex> clone_shared_agent(agent_id, user_id, workspace_id: workspace_id)
      {:ok, %Agent{}}

  ## Returns

  - `{:ok, agent}` - Successfully cloned agent
  - `{:error, :not_found}` - Agent not found
  - `{:error, :forbidden}` - User cannot clone this agent
  """
  defdelegate clone_shared_agent(agent_id, user_id, opts \\ []),
    to: CloneSharedAgent,
    as: :execute

  @doc """
  Lists all agents available in a workspace for the current user.

  Returns a map with:
  - `my_agents`: Agents owned by the current user in the workspace
  - `other_agents`: Shared agents owned by other users in the workspace

  ## Examples

      iex> list_workspace_available_agents(workspace_id, user_id)
      %{my_agents: [...], other_agents: [...]}
  """
  defdelegate list_workspace_available_agents(workspace_id, user_id),
    to: ListWorkspaceAvailableAgents,
    as: :execute

  @doc """
  Gets all agents available to a user in a workspace as a flat list.

  Combines my_agents and other_agents, respecting visibility rules:
  - User's own agents (both PRIVATE and SHARED)
  - Other users' SHARED agents only

  Optionally filters to only enabled agents.

  ## Examples

      iex> get_workspace_agents_list(workspace_id, user_id)
      [%Agent{}, ...]

      iex> get_workspace_agents_list(workspace_id, user_id, enabled_only: true)
      [%Agent{enabled: true}, ...]
  """
  def get_workspace_agents_list(workspace_id, user_id, opts \\ []) do
    result = list_workspace_available_agents(workspace_id, user_id)
    agents = (result.my_agents || []) ++ (result.other_agents || [])

    if Keyword.get(opts, :enabled_only, false) do
      Enum.filter(agents, & &1.enabled)
    else
      agents
    end
  end

  @doc """
  Gets all workspace IDs where an agent is added.

  ## Examples

      iex> get_agent_workspace_ids(agent_id)
      ["workspace-id-1", "workspace-id-2"]
  """
  def get_agent_workspace_ids(agent_id) do
    alias Agents.Infrastructure.Repositories.WorkspaceAgentRepository
    WorkspaceAgentRepository.get_agent_workspace_ids(agent_id)
  end

  @doc """
  Syncs an agent's workspace associations.

  Adds agent to selected workspaces and removes from unselected ones.
  Only the agent owner can manage workspace associations.

  ## Examples

      iex> sync_agent_workspaces(agent_id, user_id, ["workspace-1", "workspace-2"])
      :ok
  """
  def sync_agent_workspaces(agent_id, user_id, workspace_ids) do
    SyncAgentWorkspaces.execute(agent_id, user_id, workspace_ids)
  end

  @doc """
  Cancels an active agent query.

  Terminates the streaming process for the given node_id.

  ## Parameters
    - query_pid: Process PID returned from agent_query/2
    - node_id: Node ID for the query

  ## Examples

      iex> {:ok, pid} = Agents.agent_query(params, self())
      iex> Agents.cancel_agent_query(pid, "node_123")
      :ok

  """
  @spec cancel_agent_query(pid(), String.t()) :: :ok
  def cancel_agent_query(query_pid, node_id) when is_pid(query_pid) and is_binary(node_id) do
    # Send cancel signal to the query process
    send(query_pid, {:cancel, node_id})
    :ok
  end

  # ---------------------------------------------------------------------------
  # Knowledge MCP — workspace-scoped knowledge base via MCP tools
  # ---------------------------------------------------------------------------

  alias Agents.Application.UseCases.{
    AuthenticateMcpRequest,
    BootstrapKnowledgeSchema,
    CreateKnowledgeEntry,
    UpdateKnowledgeEntry,
    GetKnowledgeEntry,
    SearchKnowledgeEntries,
    TraverseKnowledgeGraph,
    CreateKnowledgeRelationship
  }

  @doc "Authenticates an MCP API key token and resolves workspace context."
  @spec authenticate_mcp(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def authenticate_mcp(token, opts \\ []) do
    AuthenticateMcpRequest.execute(token, opts)
  end

  @doc "Bootstraps the knowledge graph schema for a workspace (idempotent)."
  @spec bootstrap_knowledge_schema(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def bootstrap_knowledge_schema(workspace_id, opts \\ []) do
    BootstrapKnowledgeSchema.execute(workspace_id, opts)
  end

  @doc "Creates a new knowledge entry in a workspace."
  @spec create_knowledge_entry(String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, atom()}
  def create_knowledge_entry(workspace_id, attrs, opts \\ []) do
    CreateKnowledgeEntry.execute(workspace_id, attrs, opts)
  end

  @doc "Updates an existing knowledge entry."
  @spec update_knowledge_entry(String.t(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, atom()}
  def update_knowledge_entry(workspace_id, entry_id, attrs, opts \\ []) do
    UpdateKnowledgeEntry.execute(workspace_id, entry_id, attrs, opts)
  end

  @doc "Gets a knowledge entry with its relationships."
  @spec get_knowledge_entry(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def get_knowledge_entry(workspace_id, entry_id, opts \\ []) do
    GetKnowledgeEntry.execute(workspace_id, entry_id, opts)
  end

  @doc "Searches knowledge entries by keyword, tags, and/or category."
  @spec search_knowledge_entries(String.t(), map(), keyword()) ::
          {:ok, [struct()]} | {:error, atom()}
  def search_knowledge_entries(workspace_id, params, opts \\ []) do
    SearchKnowledgeEntries.execute(workspace_id, params, opts)
  end

  @doc "Traverses the knowledge graph from a starting entry."
  @spec traverse_knowledge_graph(String.t(), map(), keyword()) ::
          {:ok, [struct()]} | {:error, atom()}
  def traverse_knowledge_graph(workspace_id, params, opts \\ []) do
    TraverseKnowledgeGraph.execute(workspace_id, params, opts)
  end

  @doc "Creates a relationship between two knowledge entries."
  @spec create_knowledge_relationship(String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, atom()}
  def create_knowledge_relationship(workspace_id, params, opts \\ []) do
    CreateKnowledgeRelationship.execute(workspace_id, params, opts)
  end
end
