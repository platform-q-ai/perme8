defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListWorkspacesTool do
  @moduledoc "List workspaces accessible to the authenticated user."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.ListWorkspaces

  schema do
  end

  @impl true
  def execute(_params, frame) do
    user_id = frame.assigns[:user_id]

    case ListWorkspaces.execute(user_id) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No workspaces found."), frame}

      {:ok, workspaces} ->
        text = format_workspaces(workspaces)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, reason} ->
        Logger.error("ListWorkspacesTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_workspaces(workspaces) do
    workspaces
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {ws, idx} ->
      "#{idx}. **#{ws.name}** (`#{ws.slug}`)"
    end)
  end
end
