defmodule KnowledgeMcp.Infrastructure.ErmGateway do
  @moduledoc """
  Thin adapter implementing ErmGatewayBehaviour by delegating to the
  EntityRelationshipManager facade in-process.

  Each function is a simple delegation that maps the behaviour's interface
  to the ERM facade's public API.
  """

  @behaviour KnowledgeMcp.Application.Behaviours.ErmGatewayBehaviour

  @impl true
  def get_schema(workspace_id) do
    EntityRelationshipManager.get_schema(workspace_id)
  end

  @impl true
  def upsert_schema(workspace_id, attrs) do
    EntityRelationshipManager.upsert_schema(workspace_id, attrs)
  end

  @impl true
  def create_entity(workspace_id, attrs) do
    EntityRelationshipManager.create_entity(workspace_id, attrs)
  end

  @impl true
  def get_entity(workspace_id, entity_id) do
    EntityRelationshipManager.get_entity(workspace_id, entity_id)
  end

  @impl true
  def update_entity(workspace_id, entity_id, attrs) do
    EntityRelationshipManager.update_entity(workspace_id, entity_id, attrs)
  end

  @impl true
  def list_entities(workspace_id, filters) do
    EntityRelationshipManager.list_entities(workspace_id, filters)
  end

  @impl true
  def create_edge(workspace_id, attrs) do
    EntityRelationshipManager.create_edge(workspace_id, attrs)
  end

  @impl true
  def list_edges(workspace_id, filters) do
    EntityRelationshipManager.list_edges(workspace_id, filters)
  end

  @impl true
  def get_neighbors(workspace_id, entity_id, opts) do
    EntityRelationshipManager.get_neighbors(workspace_id, entity_id, opts)
  end

  @impl true
  def traverse(workspace_id, start_id, opts) do
    erm_opts = Keyword.put(opts, :start_id, start_id)
    EntityRelationshipManager.traverse(workspace_id, erm_opts)
  end
end
