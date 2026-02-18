defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetDocumentTool do
  @moduledoc "Retrieve a single document by slug within the current workspace."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.GetDocument

  schema do
    field(:slug, {:required, :string}, description: "Document slug")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    case GetDocument.execute(user_id, workspace_id, params.slug) do
      {:ok, document} ->
        text = format_document(document)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :document_not_found} ->
        {:reply, Response.error(Response.tool(), "Document not found."), frame}

      {:error, :forbidden} ->
        {:reply, Response.error(Response.tool(), "Access denied."), frame}

      {:error, reason} ->
        Logger.error("GetDocumentTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_document(doc) do
    visibility = if doc[:is_public], do: "public", else: "private"

    """
    **#{doc.title}**
    - **Slug**: `#{doc.slug}`
    - **ID**: #{doc.id}
    - **Visibility**: #{visibility}
    """
    |> String.trim()
  end
end
