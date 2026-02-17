defmodule Agents.Infrastructure.Mcp.Router do
  @moduledoc """
  Plug router composing AuthPlug with the Hermes StreamableHTTP transport.

  Authenticated requests are forwarded to the Hermes MCP transport with
  workspace_id and user_id available in conn.assigns. A `/health` endpoint
  is available without authentication for liveness checks.

  ## Mounting

  Mount in a Phoenix router:

      forward "/mcp", Agents.Infrastructure.Mcp.Router

  Or use standalone with Bandit:

      {Bandit, plug: Agents.Infrastructure.Mcp.Router, port: 4007}
  """

  use Plug.Router

  alias Agents.Infrastructure.Mcp.McpPipeline
  alias Agents.Infrastructure.Mcp.SecurityHeadersPlug

  plug(SecurityHeadersPlug)
  plug(:match)
  plug(:dispatch)

  # Health check — no auth required
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", service: "knowledge-mcp"}))
  end

  # All MCP requests require authentication
  forward("/",
    to: McpPipeline,
    init_opts: [server: Agents.Infrastructure.Mcp.Server]
  )
end
