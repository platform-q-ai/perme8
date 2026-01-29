defmodule Workspaces.Api.ActionSteps do
  @moduledoc """
  Action step definitions for Workspace API Access feature tests.

  These steps perform HTTP requests to the API endpoints.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Plug.Conn
  import Jarga.Test.StepHelpers, only: [build_conn_with_sandbox: 0]

  # ============================================================================
  # API REQUEST STEPS
  # ============================================================================

  step "I make a GET request to {string} with API key {string}",
       %{args: [path, key_name]} = context do
    api_tokens = context[:api_tokens] || %{}
    plain_token = Map.get(api_tokens, key_name)

    # Translate workspace slug in path to actual slug from context
    actual_path = translate_workspace_slug_in_path(path, context)

    # Build a conn with sandbox metadata header for proper DB connection sharing
    conn =
      build_conn_with_sandbox()
      |> put_req_header("accept", "application/json")

    conn =
      if plain_token do
        put_req_header(conn, "authorization", "Bearer #{plain_token}")
      else
        # Invalid key - use the key_name as the token (will be invalid)
        put_req_header(conn, "authorization", "Bearer #{key_name}")
      end

    # Make the request
    conn = get(conn, actual_path)

    {:ok,
     context
     |> Map.put(:response_conn, conn)
     |> Map.put(:response_status, conn.status)
     |> Map.put(:response_body, conn.resp_body)}
  end

  # Translate workspace slugs in API paths from feature file slugs to actual slugs
  # For example: /api/workspaces/product-team/projects -> /api/workspaces/product-team-abc123/projects
  defp translate_workspace_slug_in_path(path, context) do
    workspaces = context[:workspaces] || %{}

    # Pattern: /api/workspaces/:slug/... or /api/workspaces/:slug
    case Regex.run(~r{^(/api/workspaces/)([^/]+)(.*)$}, path) do
      [_, prefix, slug_in_path, suffix] ->
        # Look up workspace by the slug from the feature file
        case Map.get(workspaces, slug_in_path) do
          %{slug: actual_slug} when actual_slug != slug_in_path ->
            # Use the actual workspace slug
            prefix <> actual_slug <> suffix

          _ ->
            # No translation needed
            path
        end

      nil ->
        # Path doesn't match workspace pattern
        path
    end
  end
end
