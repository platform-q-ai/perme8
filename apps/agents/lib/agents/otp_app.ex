defmodule Agents.OTPApp do
  @moduledoc """
  OTP Application for the Agents bounded context.

  Starts the MCP server for knowledge tools alongside any other
  agent-related processes. Optionally starts a standalone Bandit HTTP
  server to expose the MCP endpoint when `:mcp_http` is configured.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Hermes.Server.Registry,
        {Registry, keys: :unique, name: Agents.Sessions.TaskRegistry},
        Agents.Sessions.Infrastructure.TaskRunnerSupervisor
      ] ++ mcp_children() ++ mcp_http_children()

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

  # Starts a standalone Bandit HTTP server for the MCP router when configured.
  # Config example: config :agents, :mcp_http, port: 4007
  defp mcp_http_children do
    case Application.get_env(:agents, :mcp_http) do
      nil ->
        []

      opts when is_list(opts) ->
        port = Keyword.get(opts, :port, 4007)

        [
          {Bandit, plug: Agents.Infrastructure.Mcp.Router, port: port, scheme: :http}
        ]
    end
  end
end
