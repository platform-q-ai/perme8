defmodule Workspaces.Api.ActionSteps do
  @moduledoc """
  Action step definitions for Workspace API Access feature tests.

  These steps perform HTTP requests to the API endpoints.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest

  # ============================================================================
  # API REQUEST STEPS
  # ============================================================================

  step "I make a GET request to {string} with API key {string}",
       %{args: [path, key_name]} = context do
    api_tokens = context[:api_tokens] || %{}
    plain_token = Map.get(api_tokens, key_name)

    # Build a fresh conn with API key authorization header
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")

    conn =
      if plain_token do
        put_req_header(conn, "authorization", "Bearer #{plain_token}")
      else
        # Invalid key - use the key_name as the token (will be invalid)
        put_req_header(conn, "authorization", "Bearer #{key_name}")
      end

    # Make the request
    conn = get(conn, path)

    {:ok,
     context
     |> Map.put(:response_conn, conn)
     |> Map.put(:response_status, conn.status)
     |> Map.put(:response_body, conn.resp_body)}
  end
end
