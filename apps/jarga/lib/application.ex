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
    children =
      [
        Jarga.Repo,
        {DNSCluster, query: Application.get_env(:jarga, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Jarga.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: Jarga.Finch}
      ] ++ pubsub_subscribers()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jarga.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # PubSub subscribers are started in non-test environments
  # In test, they are only started if explicitly enabled via config
  # (for integration tests with async: false that need real PubSub notifications)
  defp pubsub_subscribers do
    env = Application.get_env(:jarga, :env)
    enable_in_test = Application.get_env(:jarga, :enable_pubsub_in_test, false)

    if env != :test or enable_in_test do
      [Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber]
    else
      []
    end
  end
end
