defmodule Webhooks.App do
  @moduledoc false

  use Application

  use Boundary, deps: [Webhooks], exports: []

  @impl true
  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: Webhooks.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
