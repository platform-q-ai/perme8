defmodule KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationship do
  @moduledoc """
  Creates a typed relationship between two knowledge entries.

  Validates the relationship type, checks for self-reference, verifies
  both entries exist, bootstraps schema, and creates the ERM edge.
  """

  alias KnowledgeMcp.Application.GatewayConfig
  alias KnowledgeMcp.Application.UseCases.BootstrapKnowledgeSchema
  alias KnowledgeMcp.Domain.Entities.KnowledgeRelationship
  alias KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy

  @doc """
  Creates a knowledge relationship.

  ## Params

    * `from_id` - Source entry ID
    * `to_id` - Target entry ID
    * `type` - Relationship type

  ## Options

    * `:erm_gateway` - Module implementing ErmGatewayBehaviour
  """
  @spec execute(String.t(), map(), keyword()) ::
          {:ok, KnowledgeRelationship.t()} | {:error, atom()}
  def execute(workspace_id, params, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())
    from_id = Map.fetch!(params, :from_id)
    to_id = Map.fetch!(params, :to_id)
    type = Map.fetch!(params, :type)

    with :ok <- KnowledgeValidationPolicy.validate_self_reference(from_id, to_id),
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

  defp validate_type(type) do
    if KnowledgeValidationPolicy.valid_relationship_type?(type) do
      :ok
    else
      {:error, :invalid_relationship_type}
    end
  end
end
