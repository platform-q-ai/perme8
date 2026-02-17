defmodule KnowledgeMcp.Infrastructure.Mcp.Router do
  @moduledoc """
  Plug router composing AuthPlug with the Hermes StreamableHTTP transport.

  All requests pass through authentication first. Authenticated requests
  are forwarded to the Hermes MCP transport with workspace_id and user_id
  available in conn.assigns (which Hermes passes through as frame context).

  ## Mounting

  Mount in a Phoenix router:

      forward "/mcp", KnowledgeMcp.Infrastructure.Mcp.Router

  Or use standalone with Bandit/Cowboy:

      Bandit.start_link(plug: KnowledgeMcp.Infrastructure.Mcp.Router, port: 4002)
  """

  use Plug.Router

  alias KnowledgeMcp.Infrastructure.Mcp.AuthPlug
  alias KnowledgeMcp.Infrastructure.Mcp.Server

  plug(:match)
  plug(AuthPlug)
  plug(:dispatch)

  forward("/",
    to: Hermes.Server.Transport.StreamableHTTP.Plug,
    init_opts: [server: Server]
  )
end
