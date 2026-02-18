defmodule Agents.Application.UseCases.CreateKnowledgeRelationship do
  @moduledoc """
  Creates a typed relationship between two knowledge entries.

  Validates the relationship type, checks for self-reference, verifies
  both entries exist, bootstraps schema, and creates the ERM edge.
  """

  alias Agents.Application.GatewayConfig
  alias Agents.Application.UseCases.BootstrapKnowledgeSchema
  alias Agents.Domain.Entities.KnowledgeRelationship
  alias Agents.Domain.Policies.KnowledgeValidationPolicy

  @spec execute(String.t(), map(), keyword()) ::
          {:ok, KnowledgeRelationship.t()} | {:error, atom()}
  def execute(workspace_id, params, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

    with {:ok, from_id} <- fetch_required(params, :from_id),
         {:ok, to_id} <- fetch_required(params, :to_id),
         {:ok, type} <- fetch_required(params, :type),
         :ok <- KnowledgeValidationPolicy.validate_self_reference(from_id, to_id),
         :ok <- validate_type(type),
         {:ok, _} <- BootstrapKnowledgeSchema.execute(workspace_id, opts),
         {:ok, _} <- erm_gateway.get_entity(workspace_id, from_id),
         {:ok, _} <- erm_gateway.get_entity(workspace_id, to_id),
         {:ok, edge} <-
           erm_gateway.create_edge(workspace_id, %{
             source_id: from_id,
             target_id: to_id,
             type: type
           }) do
      {:ok, KnowledgeRelationship.from_erm_edge(edge)}
    end
  end

  defp fetch_required(map, key) do
    case Map.fetch(map, key) do
      {:ok, _value} = ok -> ok
      :error -> {:error, :missing_required_param}
    end
  end

  defp validate_type(type) do
    if KnowledgeValidationPolicy.valid_relationship_type?(type) do
      :ok
    else
      {:error, :invalid_relationship_type}
    end
  end
end
