defmodule KnowledgeMcp.Infrastructure.Mcp.Tools.SearchTool do
  @moduledoc "Search knowledge entries by keyword, tags, and/or category"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias KnowledgeMcp.Application.UseCases.SearchKnowledgeEntries

  schema do
    field(:query, :string, description: "Search query keyword")
    field(:tags, {:list, :string}, description: "Filter by tags (AND logic)")
    field(:category, :string, description: "Filter by category")
    field(:limit, :integer, description: "Max results (1-100, default 20)")
  end

  @impl true
  def execute(params, frame) do
    workspace_id = frame.assigns[:workspace_id]

    search_params = %{
      query: Map.get(params, :query),
      tags: Map.get(params, :tags),
      category: Map.get(params, :category),
      limit: Map.get(params, :limit)
    }

    case SearchKnowledgeEntries.execute(workspace_id, search_params) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No results found."), frame}

      {:ok, entries} ->
        text = format_results(entries)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :empty_search} ->
        {:reply,
         Response.error(
           Response.tool(),
           "Please provide at least one search criteria: query, tags, or category."
         ), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Search failed: #{reason}"), frame}
    end
  end

  defp format_results(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {entry, idx} ->
      tags = if entry.tags != [], do: " [#{Enum.join(entry.tags, ", ")}]", else: ""

      "#{idx}. **#{entry.title}** (#{entry.category})#{tags}\n#{entry.body}"
    end)
  end
end
