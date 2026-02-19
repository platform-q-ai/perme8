defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetProjectTool do
  @moduledoc "Retrieve a single project by slug within the current workspace."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.GetProject

  schema do
    field(:slug, {:required, :string}, description: "Project slug")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    case GetProject.execute(user_id, workspace_id, params.slug) do
      {:ok, project} ->
        text = format_project(project)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, :project_not_found} ->
        {:reply, Response.error(Response.tool(), "Project not found."), frame}

      {:error, reason} ->
        Logger.error("GetProjectTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_project(project) do
    desc = if project[:description], do: "\n- **Description**: #{project.description}", else: ""

    """
    **#{project.name}**
    - **Slug**: `#{project.slug}`
    - **ID**: #{project.id}#{desc}
    """
    |> String.trim()
  end
end
