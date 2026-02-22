defmodule AgentsWeb.Application do
  @moduledoc false

  use Application
  use Boundary, deps: [Agents, AgentsWeb], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      AgentsWeb.Telemetry,
      AgentsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AgentsWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AgentsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
