defmodule KnowledgeMcp.Application do
  @moduledoc """
  OTP Application for the Knowledge MCP server.

  Starts the Hermes Server Registry and the MCP Server supervision tree,
  configuring transport based on application environment.
  """

  use Application

  @impl true
  def start(_type, _args) do
    transport = Application.get_env(:knowledge_mcp, :mcp_transport, default_transport())

    children = [
      Hermes.Server.Registry,
      {KnowledgeMcp.Infrastructure.Mcp.Server, transport: transport}
    ]

    opts = [strategy: :one_for_one, name: KnowledgeMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp default_transport do
    {:streamable_http, []}
  end
end
