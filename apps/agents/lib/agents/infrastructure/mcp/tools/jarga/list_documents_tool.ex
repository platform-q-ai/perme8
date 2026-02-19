defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListDocumentsTool do
  @moduledoc "List documents in the current workspace, optionally filtered by project."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.ListDocuments

  schema do
    field(:project_slug, :string, description: "Optional: filter by project slug")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    filter_params = build_filter_params(params)

    case ListDocuments.execute(user_id, workspace_id, filter_params) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No documents found."), frame}

      {:ok, documents} ->
        text = format_documents(documents)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :project_not_found} ->
        {:reply, Response.error(Response.tool(), "Project not found."), frame}

      {:error, reason} ->
        Logger.error("ListDocumentsTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp build_filter_params(params) do
    case Map.get(params, :project_slug) do
      nil -> %{}
      slug -> %{project_slug: slug}
    end
  end

  defp format_documents(documents) do
    documents
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {doc, idx} ->
      visibility = if doc[:is_public], do: "public", else: "private"
      "#{idx}. **#{doc.title}** (`#{doc.slug}`) [#{visibility}]"
    end)
  end
end
