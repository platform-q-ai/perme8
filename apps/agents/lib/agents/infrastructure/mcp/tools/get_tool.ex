defmodule Agents.Infrastructure.Mcp.Tools.GetTool do
  @moduledoc "Get a knowledge entry by ID with its relationships"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.GetKnowledgeEntry

  schema do
    field(:id, {:required, :string}, description: "Knowledge entry ID")
  end

  @impl true
  def execute(%{id: entry_id}, frame) do
    workspace_id = frame.assigns[:workspace_id]

    case GetKnowledgeEntry.execute(workspace_id, entry_id) do
      {:ok, %{entry: entry, relationships: relationships}} ->
        text = format_entry(entry, relationships)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "Knowledge entry not found."), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Failed to get entry: #{reason}"), frame}
    end
  end

  defp format_entry(entry, relationships) do
    rel_text =
      if relationships == [] do
        "None"
      else
        relationships
        |> Enum.map_join("\n", fn rel ->
          "  - #{rel.type}: #{rel.from_id} -> #{rel.to_id}"
        end)
      end

    """
    # #{entry.title}

    **Category**: #{entry.category}
    **Tags**: #{Enum.join(entry.tags, ", ")}
    **ID**: #{entry.id}
    **Created**: #{entry.created_at}
    **Updated**: #{entry.updated_at}

    #{entry.body}

    ## Relationships
    #{rel_text}
    """
    |> String.trim()
  end
end
