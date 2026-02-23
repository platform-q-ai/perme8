defmodule Webhooks.App do
  @moduledoc false

  use Application

  use Boundary, deps: [Webhooks], exports: []

  @impl true
  def start(_type, _args) do
    children = pubsub_subscribers() ++ workers()

    opts = [strategy: :one_for_one, name: Webhooks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Only start PubSub subscribers and workers outside of test env
  # (unless explicitly enabled via config for integration tests)
  defp pubsub_subscribers do
    if start_background_processes?() do
      [Webhooks.Infrastructure.Subscribers.OutboundWebhookHandler]
    else
      []
    end
  end

  defp workers do
    if start_background_processes?() do
      [Webhooks.Infrastructure.Workers.RetryWorker]
    else
      []
    end
  end

  defp start_background_processes? do
    env = Application.get_env(:webhooks, :env)
    enable_in_test = Application.get_env(:webhooks, :enable_pubsub_in_test, false)

    env != :test or enable_in_test
  end
end
