defmodule Agents.Infrastructure.Mcp.Tools.CreateTool do
  @moduledoc "Create a new knowledge entry"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.CreateKnowledgeEntry

  schema do
    field(:title, {:required, :string}, description: "Entry title (max 255 chars)")
    field(:body, {:required, :string}, description: "Entry body (Markdown)")

    field(:category, {:required, :string},
      description: "Category: how_to, pattern, convention, architecture_decision, gotcha, concept"
    )

    field(:tags, {:list, :string}, description: "Tags for categorization")
    field(:code_snippets, {:list, :string}, description: "Code snippet JSON strings")
    field(:file_paths, {:list, :string}, description: "Related file paths")
    field(:external_links, {:list, :string}, description: "External reference URLs")
  end

  @impl true
  def execute(params, frame) do
    workspace_id = frame.assigns[:workspace_id]

    attrs = %{
      title: params.title,
      body: params.body,
      category: params.category,
      tags: Map.get(params, :tags) || [],
      code_snippets: Map.get(params, :code_snippets) || [],
      file_paths: Map.get(params, :file_paths) || [],
      external_links: Map.get(params, :external_links) || []
    }

    case CreateKnowledgeEntry.execute(workspace_id, attrs) do
      {:ok, entry} ->
        text = format_created(entry)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), format_error(reason)), frame}
    end
  end

  defp format_created(entry) do
    """
    Created knowledge entry:
    - **ID**: #{entry.id}
    - **Title**: #{entry.title}
    - **Category**: #{entry.category}
    - **Tags**: #{Enum.join(entry.tags, ", ")}
    """
    |> String.trim()
  end

  defp format_error(:title_required), do: "Title is required and cannot be empty."
  defp format_error(:body_required), do: "Body is required and cannot be empty."

  defp format_error(:invalid_category),
    do:
      "Invalid category. Valid categories: how_to, pattern, convention, architecture_decision, gotcha, concept."

  defp format_error(:title_too_long), do: "Title must be 255 characters or less."
  defp format_error(:too_many_tags), do: "Maximum of 20 tags allowed."
  defp format_error(:invalid_tag), do: "Tags must be non-empty strings."
  defp format_error(reason), do: "Failed to create entry: #{inspect(reason)}"
end
