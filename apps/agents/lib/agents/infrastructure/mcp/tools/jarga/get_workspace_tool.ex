defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetWorkspaceTool do
  @moduledoc "Retrieve a single workspace by slug."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.GetWorkspace

  schema do
    field(:slug, {:required, :string}, description: "Workspace slug")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]

    case GetWorkspace.execute(user_id, params.slug) do
      {:ok, workspace} ->
        text = format_workspace(workspace)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "Workspace not found."), frame}

      {:error, :unauthorized} ->
        {:reply, Response.error(Response.tool(), "Unauthorized."), frame}

      {:error, reason} ->
        Logger.error("GetWorkspaceTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_workspace(ws) do
    """
    **#{ws.name}**
    - **Slug**: `#{ws.slug}`
    - **ID**: #{ws.id}
    """
    |> String.trim()
  end
end
