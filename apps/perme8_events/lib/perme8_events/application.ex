defmodule Perme8Events.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: pubsub_name()}
    ]

    opts = [strategy: :one_for_one, name: Perme8Events.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pubsub_name do
    Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub)
  end
end
