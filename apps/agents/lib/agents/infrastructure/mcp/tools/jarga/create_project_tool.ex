defmodule Agents.Infrastructure.Mcp.Tools.Jarga.CreateProjectTool do
  @moduledoc "Create a new project within the current workspace."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.CreateProject

  schema do
    field(:name, {:required, :string}, description: "Project name")
    field(:description, :string, description: "Project description")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    attrs = %{name: params.name}

    attrs =
      case Map.get(params, :description) do
        nil -> attrs
        description -> Map.put(attrs, :description, description)
      end

    case CreateProject.execute(user_id, workspace_id, attrs) do
      {:ok, project} ->
        text = format_created(project)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, Response.error(Response.tool(), format_changeset(changeset)), frame}

      {:error, reason} ->
        Logger.error("CreateProjectTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp format_created(project) do
    """
    Created project:
    - **Name**: #{project.name}
    - **Slug**: `#{project.slug}`
    """
    |> String.trim()
  end

  defp format_changeset(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        atom_key =
          try do
            String.to_existing_atom(key)
          rescue
            ArgumentError -> nil
          end

        case atom_key && Keyword.get(opts, atom_key) do
          nil -> key
          value -> to_string(value)
        end
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
