defmodule Agents.OTPApp do
  @moduledoc """
  OTP Application for the Agents bounded context.

  Starts the MCP server for knowledge tools alongside any other
  agent-related processes.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Hermes.Server.Registry
      ] ++ mcp_children()

    opts = [strategy: :one_for_one, name: Agents.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mcp_children do
    transport = mcp_transport()

    [{Agents.Infrastructure.Mcp.Server, transport: transport}]
  end

  defp mcp_transport do
    Application.get_env(:agents, :mcp_transport, {:streamable_http, []})
  end
end
