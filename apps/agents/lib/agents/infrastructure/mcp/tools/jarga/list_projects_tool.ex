defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListProjectsTool do
  @moduledoc "List projects within the current workspace."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.ListProjects

  schema do
  end

  @impl true
  def execute(_params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    case ListProjects.execute(user_id, workspace_id) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No projects found."), frame}

      {:ok, projects} ->
        text = format_projects(projects)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, reason} ->
        Logger.error("ListProjectsTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_projects(projects) do
    projects
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {project, idx} ->
      desc = if project[:description], do: " — #{project.description}", else: ""
      "#{idx}. **#{project.name}** (`#{project.slug}`)#{desc}"
    end)
  end
end
