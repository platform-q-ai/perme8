defmodule Chat.OTPApp do
  @moduledoc """
  OTP Application for the Chat bounded context.

  Starts Chat.Repo.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Repo],
    exports: []

  use Application

  @impl true
  def start(_type, _args) do
    children = [Chat.Repo]

    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
