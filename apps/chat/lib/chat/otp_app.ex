defmodule Chat.OTPApp do
  @moduledoc """
  OTP Application for the Chat bounded context.

  Starts Chat.Repo, the IdentityEventSubscriber (for MemberRemoved cleanup),
  and the OrphanDetectionWorker (defense-in-depth orphan cleanup).
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Repo, Chat.Infrastructure, Perme8.Events],
    exports: []

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [Chat.Repo] ++ infrastructure_children()

    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp infrastructure_children do
    if Application.get_env(:chat, :start_infrastructure, true) do
      [
        Chat.Infrastructure.Subscribers.IdentityEventSubscriber,
        Chat.Infrastructure.Workers.OrphanDetectionWorker
      ]
    else
      []
    end
  end
end
