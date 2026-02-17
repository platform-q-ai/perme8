defmodule Agents.Infrastructure.Mcp.McpPipeline do
  @moduledoc """
  Plug pipeline that chains AuthPlug with the Hermes StreamableHTTP transport.

  Used by the MCP Router to authenticate requests before forwarding them
  to the Hermes MCP server. If authentication fails (conn is halted),
  the request is not forwarded.
  """

  @behaviour Plug

  alias Agents.Infrastructure.Mcp.AuthPlug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    case AuthPlug.call(conn, AuthPlug.init([])) do
      %Plug.Conn{halted: true} = halted_conn ->
        halted_conn

      authenticated_conn ->
        server = Keyword.fetch!(opts, :server)

        Hermes.Server.Transport.StreamableHTTP.Plug.call(
          authenticated_conn,
          Hermes.Server.Transport.StreamableHTTP.Plug.init(server: server)
        )
    end
  end
end
