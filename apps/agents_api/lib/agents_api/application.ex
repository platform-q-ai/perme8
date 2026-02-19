defmodule AgentsApi.Application do
  @moduledoc false

  use Application

  use Boundary, deps: [AgentsApi], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      AgentsApi.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AgentsApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AgentsApi.Endpoint.config_change(changed, removed)
    :ok
  end
end
