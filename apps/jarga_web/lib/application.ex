defmodule JargaWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # Interface layer - can depend on Core contexts but not vice versa
  use Boundary, deps: [Jarga, JargaWeb], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      JargaWeb.Telemetry,
      # Registry for DocumentSaveDebouncer processes
      {Registry, keys: :unique, name: JargaWeb.DocumentSaveDebouncerRegistry},
      # DynamicSupervisor for DocumentSaveDebouncer processes
      JargaWeb.DocumentSaveDebouncerSupervisor,
      # Start to serve requests, typically the last entry
      JargaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JargaWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JargaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
