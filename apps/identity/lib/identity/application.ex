defmodule Identity.OTPApp do
  @moduledoc """
  OTP Application for the Identity bounded context.

  The Identity app provides user management, authentication, authorization,
  and API key functionality. It has its own endpoint (IdentityWeb.Endpoint)
  that serves authentication routes directly.

  Note: Named `Identity.OTPApp` instead of `Identity.Application` to avoid
  namespace collision with `Identity.Application.*` use cases and behaviours.
  """

  use Application

  # OTP Application supervisor - needs access to both Identity and IdentityWeb
  # Top-level boundary to be sibling to Identity and IdentityWeb
  use Boundary, top_level?: true, deps: [Identity, IdentityWeb], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      IdentityWeb.Telemetry,
      # Start to serve requests, typically the last entry
      IdentityWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Identity.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IdentityWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
