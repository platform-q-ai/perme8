defmodule Agents.Infrastructure.Mcp.Tools.TraverseTool do
  @moduledoc "Traverse the knowledge graph from a starting entry"

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.TraverseKnowledgeGraph
  alias Agents.Domain.Policies.KnowledgeValidationPolicy

  schema do
    field(:id, {:required, :string}, description: "Starting entry ID")
    field(:relationship_type, :string, description: "Filter by relationship type")
    field(:depth, :integer, description: "Traversal depth (1-5, default 2)")
  end

  @impl true
  def execute(params, frame) do
    workspace_id = frame.assigns[:workspace_id]

    traverse_params = %{
      start_id: params.id,
      relationship_type: Map.get(params, :relationship_type),
      depth: Map.get(params, :depth)
    }

    case TraverseKnowledgeGraph.execute(workspace_id, traverse_params) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No connected entries found."), frame}

      {:ok, entries} ->
        text = format_traversal(entries)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "Starting entry not found."), frame}

      {:error, :invalid_relationship_type} ->
        valid = KnowledgeValidationPolicy.relationship_types()

        {:reply,
         Response.error(
           Response.tool(),
           "Invalid relationship type. Valid types: #{Enum.join(valid, ", ")}"
         ), frame}

      {:error, reason} ->
        Logger.error("TraverseTool unexpected error: #{inspect(reason)}")

        {:reply,
         Response.error(Response.tool(), "An unexpected error occurred during traversal."), frame}
    end
  end

  defp format_traversal(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {entry, idx} ->
      "#{idx}. **#{entry.title}** (#{entry.category}) [#{entry.id}]"
    end)
  end
end
