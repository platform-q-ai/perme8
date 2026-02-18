defmodule Agents.Application.UseCases.CreateDocument do
  @moduledoc """
  Creates a new document within a workspace.

  Handles two transformations before delegating to the gateway:

  1. **Project slug resolution** — If `project_slug` is present in attrs,
     resolves it to a `project_id` via the gateway and replaces it in attrs.
  2. **Visibility translation** — Translates `visibility` ("public"/"private"/nil)
     to `is_public` (boolean). Defaults to `false` when absent or nil.
  """

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(user_id, workspace_id, attrs, opts \\ []) do
    jarga_gateway = Keyword.get(opts, :jarga_gateway, GatewayConfig.jarga_gateway())

    with {:ok, attrs} <- resolve_project_slug(jarga_gateway, user_id, workspace_id, attrs) do
      attrs = translate_visibility(attrs)
      jarga_gateway.create_document(user_id, workspace_id, attrs)
    end
  end

  defp resolve_project_slug(jarga_gateway, user_id, workspace_id, attrs) do
    case Map.pop(attrs, :project_slug) do
      {nil, attrs} ->
        {:ok, attrs}

      {project_slug, attrs} ->
        with {:ok, project} <- jarga_gateway.get_project(user_id, workspace_id, project_slug) do
          {:ok, Map.put(attrs, :project_id, project.id)}
        end
    end
  end

  defp translate_visibility(attrs) do
    {visibility, attrs} = Map.pop(attrs, :visibility)

    is_public = visibility == "public"
    Map.put(attrs, :is_public, is_public)
  end
end
