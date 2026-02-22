defmodule Perme8Dashboard.OTPApp do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Perme8DashboardWeb],
    exports: []

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Perme8DashboardWeb.Telemetry,
      Perme8DashboardWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Perme8Dashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Perme8DashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
