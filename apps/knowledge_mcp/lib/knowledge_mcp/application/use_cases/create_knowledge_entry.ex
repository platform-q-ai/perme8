defmodule KnowledgeMcp.Application.UseCases.CreateKnowledgeEntry do
  @moduledoc """
  Creates a new knowledge entry in the ERM graph.

  Validates attributes, bootstraps schema if needed, creates the ERM entity,
  and converts the result to a KnowledgeEntry domain entity.
  """

  alias KnowledgeMcp.Application.GatewayConfig
  alias KnowledgeMcp.Application.UseCases.BootstrapKnowledgeSchema
  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy

  @doc """
  Creates a knowledge entry.

  ## Options

    * `:erm_gateway` - Module implementing ErmGatewayBehaviour
  """
  @spec execute(String.t(), map(), keyword()) :: {:ok, KnowledgeEntry.t()} | {:error, atom()}
  def execute(workspace_id, attrs, opts \\ []) do
    erm_gateway = Keyword.get(opts, :erm_gateway, GatewayConfig.erm_gateway())

    # TODO: Cache bootstrapped schema status per workspace (e.g., ETS with TTL)
    # to avoid repeated get_schema round-trips on every create/relate call.
    with :ok <- KnowledgeValidationPolicy.validate_entry_attrs(attrs),
         :ok <- validate_tags(attrs),
         {:ok, _} <- BootstrapKnowledgeSchema.execute(workspace_id, opts) do
      entry = KnowledgeEntry.new(attrs)
      properties = KnowledgeEntry.to_erm_properties(entry)

      case erm_gateway.create_entity(workspace_id, %{
             type: "KnowledgeEntry",
             properties: properties
           }) do
        {:ok, erm_entity} -> {:ok, KnowledgeEntry.from_erm_entity(erm_entity)}
        {:error, _} = error -> error
      end
    end
  end

  defp validate_tags(%{tags: tags}) when is_list(tags) do
    KnowledgeValidationPolicy.validate_tags(tags)
  end

  defp validate_tags(_), do: :ok
end
