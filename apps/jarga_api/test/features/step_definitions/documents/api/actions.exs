defmodule Documents.Api.ActionSteps do
  @moduledoc """
  Action step definitions for Document API Access feature tests.

  These steps perform HTTP requests to document-specific API endpoints,
  including PATCH for updates with optimistic concurrency control.
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias JargaApi.Test.Helpers

  # ============================================================================
  # API REQUEST STEPS
  # ============================================================================

  step "I make a PATCH request to {string} with API key {string} and body:",
       %{args: [path, key_name]} = context do
    api_tokens = context[:api_tokens] || %{}
    plain_token = Map.get(api_tokens, key_name)

    # Get JSON body from docstring
    body = context.docstring

    # Translate workspace slug and other known slugs in path to actual slugs from context
    actual_path =
      path
      |> translate_workspace_slug_in_path(context)
      |> Helpers.translate_known_slugs(context)

    # Build a conn with sandbox metadata header for proper DB connection sharing
    conn =
      Helpers.build_conn_with_sandbox()
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    conn =
      if plain_token do
        put_req_header(conn, "authorization", "Bearer #{plain_token}")
      else
        put_req_header(conn, "authorization", "Bearer #{key_name}")
      end

    # Make the PATCH request with JSON body
    conn = patch(conn, actual_path, body)

    {:ok,
     context
     |> Map.put(:response_conn, conn)
     |> Map.put(:response_status, conn.status)
     |> Map.put(:response_body, conn.resp_body)}
  end

  step "I store the content_hash from the response", context do
    body = Jason.decode!(context[:response_body])
    content_hash = body["data"]["content_hash"]

    assert content_hash != nil,
           "Expected content_hash in response, got nil. Response: #{inspect(body)}"

    {:ok, Map.put(context, :stored_content_hash, content_hash)}
  end

  step "I make a PATCH request to {string} with API key {string} using stored content_hash and body:",
       %{args: [path, key_name]} = context do
    api_tokens = context[:api_tokens] || %{}
    plain_token = Map.get(api_tokens, key_name)

    # Parse the docstring body and inject content_hash
    base_body = Jason.decode!(context.docstring)
    body = Map.put(base_body, "content_hash", context[:stored_content_hash])

    actual_path =
      path
      |> translate_workspace_slug_in_path(context)
      |> Helpers.translate_known_slugs(context)

    conn =
      Helpers.build_conn_with_sandbox()
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    conn =
      if plain_token do
        put_req_header(conn, "authorization", "Bearer #{plain_token}")
      else
        put_req_header(conn, "authorization", "Bearer #{key_name}")
      end

    conn = patch(conn, actual_path, Jason.encode!(body))

    {:ok,
     context
     |> Map.put(:response_conn, conn)
     |> Map.put(:response_status, conn.status)
     |> Map.put(:response_body, conn.resp_body)}
  end

  # Translate workspace slugs in API paths from feature file slugs to actual slugs
  defp translate_workspace_slug_in_path(path, context) do
    workspaces = context[:workspaces] || %{}

    case Regex.run(~r{^(/api/workspaces/)([^/]+)(.*)$}, path) do
      [_, prefix, slug_in_path, suffix] ->
        case Map.get(workspaces, slug_in_path) do
          %{slug: actual_slug} when actual_slug != slug_in_path ->
            prefix <> actual_slug <> suffix

          _ ->
            path
        end

      nil ->
        path
    end
  end
end
