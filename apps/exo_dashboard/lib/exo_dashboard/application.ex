defmodule ExoDashboard.OTPApp do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [ExoDashboard.Features, ExoDashboard.TestRuns, ExoDashboardWeb],
    exports: []

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExoDashboard.TestRuns.Infrastructure.ResultStore,
      ExoDashboardWeb.Telemetry,
      ExoDashboardWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ExoDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExoDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
