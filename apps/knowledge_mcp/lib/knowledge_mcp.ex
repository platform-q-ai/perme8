defmodule KnowledgeMcp do
  @moduledoc """
  Public API facade for the Knowledge MCP bounded context.

  A graph-structured, workspace-scoped knowledge base exposed via MCP tools.
  LLM agents authenticate via Identity API keys, then create, search, traverse,
  and maintain institutional knowledge entries stored as ERM graph entities.
  """

  use Boundary,
    top_level?: true,
    deps: [
      EntityRelationshipManager,
      Identity
    ],
    exports: []

  alias KnowledgeMcp.Application.UseCases

  @doc """
  Authenticates an API key token and resolves workspace context.

  Returns `{:ok, %{workspace_id: id, user_id: id}}` or `{:error, reason}`.
  """
  @spec authenticate(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def authenticate(token, opts \\ []) do
    UseCases.AuthenticateRequest.execute(token, opts)
  end

  @doc """
  Creates a new knowledge entry in a workspace.

  Returns `{:ok, knowledge_entry}` or `{:error, reason}`.
  """
  @spec create(String.t(), map(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def create(workspace_id, attrs, opts \\ []) do
    UseCases.CreateKnowledgeEntry.execute(workspace_id, attrs, opts)
  end

  @doc """
  Updates an existing knowledge entry.

  Returns `{:ok, knowledge_entry}` or `{:error, reason}`.
  """
  @spec update(String.t(), String.t(), map(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def update(workspace_id, entry_id, attrs, opts \\ []) do
    UseCases.UpdateKnowledgeEntry.execute(workspace_id, entry_id, attrs, opts)
  end

  @doc """
  Gets a knowledge entry with its relationships.

  Returns `{:ok, %{entry: knowledge_entry, relationships: [...]}}` or `{:error, reason}`.
  """
  @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def get(workspace_id, entry_id, opts \\ []) do
    UseCases.GetKnowledgeEntry.execute(workspace_id, entry_id, opts)
  end

  @doc """
  Searches knowledge entries by keyword, tags, and/or category.

  Returns `{:ok, [knowledge_entry]}` or `{:error, reason}`.
  """
  @spec search(String.t(), map(), keyword()) :: {:ok, [struct()]} | {:error, atom()}
  def search(workspace_id, params, opts \\ []) do
    UseCases.SearchKnowledgeEntries.execute(workspace_id, params, opts)
  end

  @doc """
  Traverses the knowledge graph from a starting entry.

  Returns `{:ok, [knowledge_entry]}` or `{:error, reason}`.
  """
  @spec traverse(String.t(), map(), keyword()) :: {:ok, [struct()]} | {:error, atom()}
  def traverse(workspace_id, params, opts \\ []) do
    UseCases.TraverseKnowledgeGraph.execute(workspace_id, params, opts)
  end

  @doc """
  Creates a relationship between two knowledge entries.

  Returns `{:ok, knowledge_relationship}` or `{:error, reason}`.
  """
  @spec relate(String.t(), map(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def relate(workspace_id, params, opts \\ []) do
    UseCases.CreateKnowledgeRelationship.execute(workspace_id, params, opts)
  end
end
