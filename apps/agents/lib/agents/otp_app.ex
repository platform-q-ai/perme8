defmodule Agents.OTPApp do
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Agents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
