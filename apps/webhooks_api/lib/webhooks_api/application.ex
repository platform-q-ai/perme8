defmodule WebhooksApi.Application do
  @moduledoc false

  use Application

  use Boundary, deps: [WebhooksApi], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      WebhooksApi.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WebhooksApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    WebhooksApi.Endpoint.config_change(changed, removed)
    :ok
  end
end
