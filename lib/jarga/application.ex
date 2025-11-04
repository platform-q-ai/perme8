defmodule JargaApp do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # OTP Application supervisor - sibling to Jarga and JargaWeb boundaries
  # Can depend on all parts of the application for supervision purposes
  use Boundary, deps: [Jarga, JargaWeb], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      JargaWeb.Telemetry,
      Jarga.Repo,
      {DNSCluster, query: Application.get_env(:jarga, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Jarga.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Jarga.Finch},
      # Start a worker by calling: Jarga.Worker.start_link(arg)
      # {Jarga.Worker, arg},
      # Start to serve requests, typically the last entry
      JargaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jarga.Supervisor]
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
