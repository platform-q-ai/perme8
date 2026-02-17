defmodule KnowledgeMcp.Infrastructure.Mcp.Tools.RelateTool do
  @moduledoc "Create a relationship between two knowledge entries"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationship
  alias KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy

  schema do
    field(:from_id, {:required, :string}, description: "Source entry ID")
    field(:to_id, {:required, :string}, description: "Target entry ID")

    field(:relationship_type, {:required, :string},
      description:
        "Type: relates_to, depends_on, prerequisite_for, example_of, part_of, supersedes"
    )
  end

  @impl true
  def execute(params, frame) do
    workspace_id = frame.assigns[:workspace_id]

    relate_params = %{
      from_id: params.from_id,
      to_id: params.to_id,
      type: params.relationship_type
    }

    case CreateKnowledgeRelationship.execute(workspace_id, relate_params) do
      {:ok, relationship} ->
        text = format_relationship(relationship)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :self_reference} ->
        {:reply,
         Response.error(
           Response.tool(),
           "Cannot create a self-referencing relationship. Source and target must be different entries."
         ), frame}

      {:error, :invalid_relationship_type} ->
        valid = KnowledgeValidationPolicy.relationship_types()

        {:reply,
         Response.error(
           Response.tool(),
           "Invalid relationship type. Valid types: #{Enum.join(valid, ", ")}"
         ), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "One or both entries not found."), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Failed to create relationship: #{reason}"),
         frame}
    end
  end

  defp format_relationship(rel) do
    """
    Created relationship:
    - **Type**: #{rel.type}
    - **From**: #{rel.from_id}
    - **To**: #{rel.to_id}
    - **ID**: #{rel.id}
    """
    |> String.trim()
  end
end
