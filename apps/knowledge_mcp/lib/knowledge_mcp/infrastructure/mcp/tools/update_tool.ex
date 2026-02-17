defmodule KnowledgeMcp.Infrastructure.Mcp.Tools.UpdateTool do
  @moduledoc "Update an existing knowledge entry"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntry

  schema do
    field(:id, {:required, :string}, description: "Entry ID to update")
    field(:title, :string, description: "Updated title")
    field(:body, :string, description: "Updated body")
    field(:category, :string, description: "Updated category")
    field(:tags, {:list, :string}, description: "Updated tags")
    field(:code_snippets, {:list, :string}, description: "Updated code snippets")
    field(:file_paths, {:list, :string}, description: "Updated file paths")
    field(:external_links, {:list, :string}, description: "Updated external links")
    field(:last_verified_at, :string, description: "ISO 8601 datetime for verification")
  end

  @updatable_keys ~w(title body category tags code_snippets file_paths external_links last_verified_at)a

  @impl true
  def execute(%{id: entry_id} = params, frame) do
    workspace_id = frame.assigns[:workspace_id]

    attrs =
      params
      |> Map.take(@updatable_keys)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case UpdateKnowledgeEntry.execute(workspace_id, entry_id, attrs) do
      {:ok, entry} ->
        text = format_updated(entry)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "Knowledge entry not found."), frame}

      {:error, :invalid_category} ->
        {:reply,
         Response.error(
           Response.tool(),
           "Invalid category. Valid categories: how_to, pattern, convention, architecture_decision, gotcha, concept."
         ), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Failed to update entry: #{reason}"), frame}
    end
  end

  defp format_updated(entry) do
    """
    Updated knowledge entry:
    - **ID**: #{entry.id}
    - **Title**: #{entry.title}
    - **Category**: #{entry.category}
    """
    |> String.trim()
  end
end
