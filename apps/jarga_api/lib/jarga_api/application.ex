defmodule JargaApi.Application do
  @moduledoc false

  use Application

  use Boundary, deps: [JargaApi], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      JargaApi.Endpoint
    ]

    opts = [strategy: :one_for_one, name: JargaApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    JargaApi.Endpoint.config_change(changed, removed)
    :ok
  end
end
