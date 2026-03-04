defmodule Notifications.OTPApp do
  @moduledoc """
  OTP Application for the Notifications bounded context.

  Starts the Notifications.Repo and conditionally starts PubSub subscribers.
  """
  use Boundary,
    top_level?: true,
    deps: [Notifications.Infrastructure, Notifications.Repo],
    exports: []

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

  @doc """
  Ensures PubSub event subscribers are started.

  Used by consuming apps' test support modules (e.g. Jarga.DataCase)
  to start subscribers for integration tests where the Notifications
  OTP app has subscribers disabled in test mode.

  Returns a list of subscriber PIDs (either existing or newly started).
  """
  def ensure_subscribers_started do
    Notifications.Infrastructure.Subscribers
    |> subscribers()
    |> Enum.map(&ensure_subscriber_started/1)
  end

  # PubSub subscribers are started in non-test environments.
  # In test, they are only started if explicitly enabled via config
  # (for integration tests with async: false that need real PubSub notifications).
  defp pubsub_subscribers do
    env = Application.get_env(:notifications, :env)
    enable_in_test = Application.get_env(:notifications, :enable_pubsub_in_test, false)

    if env != :test or enable_in_test do
      Notifications.Infrastructure.Subscribers
      |> subscribers()
    else
      []
    end
  end

  defp subscribers(_namespace) do
    [
      Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber,
      Notifications.Infrastructure.Subscribers.TaskCompletionSubscriber,
      Notifications.Infrastructure.Subscribers.DomainEventNotificationSubscriber
    ]
  end

  defp ensure_subscriber_started(subscriber) do
    case Process.whereis(subscriber) do
      nil ->
        case subscriber.start_link([]) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      pid ->
        pid
    end
  end
end
