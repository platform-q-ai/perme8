defmodule Notifications.OTPApp do
  @moduledoc """
  OTP Application for the Notifications bounded context.

  Starts the Notifications.Repo and conditionally starts PubSub subscribers.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Notifications.Repo
      ] ++ pubsub_subscribers()

    opts = [strategy: :one_for_one, name: Notifications.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # PubSub subscribers are started in non-test environments.
  # In test, they are only started if explicitly enabled via config
  # (for integration tests with async: false that need real PubSub notifications).
  defp pubsub_subscribers do
    env = Application.get_env(:notifications, :env)
    enable_in_test = Application.get_env(:notifications, :enable_pubsub_in_test, false)

    if env != :test or enable_in_test do
      [Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber]
    else
      []
    end
  end
end
