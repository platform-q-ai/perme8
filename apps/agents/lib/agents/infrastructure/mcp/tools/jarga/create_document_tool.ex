defmodule Agents.Infrastructure.Mcp.Tools.Jarga.CreateDocumentTool do
  @moduledoc "Create a new document within the current workspace."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Application.UseCases.CreateDocument

  schema do
    field(:title, {:required, :string}, description: "Document title")
    field(:content, :string, description: "Document content (Markdown)")

    field(:visibility, :string, description: "Visibility: public or private (default: private)")

    field(:project_slug, :string, description: "Optional: project to add document to")
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    workspace_id = frame.assigns[:workspace_id]

    attrs = build_attrs(params)

    case CreateDocument.execute(user_id, workspace_id, attrs) do
      {:ok, document} ->
        text = format_created(document)
        {:reply, Response.text(Response.tool(), text), frame}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, Response.error(Response.tool(), format_changeset(changeset)), frame}

      {:error, reason} ->
        Logger.error("CreateDocumentTool unexpected error: #{inspect(reason)}")
        {:reply, Response.error(Response.tool(), "An unexpected error occurred."), frame}
    end
  end

  defp build_attrs(params) do
    attrs = %{title: params.title}

    attrs =
      case Map.get(params, :content) do
        nil -> attrs
        content -> Map.put(attrs, :content, content)
      end

    attrs =
      case Map.get(params, :visibility) do
        nil -> attrs
        visibility -> Map.put(attrs, :visibility, visibility)
      end

    case Map.get(params, :project_slug) do
      nil -> attrs
      project_slug -> Map.put(attrs, :project_slug, project_slug)
    end
  end

  defp format_created(document) do
    """
    Created document:
    - **Title**: #{document.title}
    - **Slug**: `#{document.slug}`
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
