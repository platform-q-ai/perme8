defmodule Jarga.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # OTP Application supervisor - sibling to Jarga boundary
  # Can depend on all parts of the application for supervision purposes
  use Boundary, deps: [Jarga], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      Jarga.Repo,
      {DNSCluster, query: Application.get_env(:jarga, :dns_cluster_query) || :ignore},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Jarga.Finch}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jarga.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
