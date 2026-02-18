defmodule Agents.Application.GatewayConfig do
  @moduledoc """
  Runtime gateway and service configuration.

  Resolves which `ErmGatewayBehaviour`, `IdentityBehaviour`, and
  `JargaGatewayBehaviour` implementations to use. Uses `Application.get_env/3`
  for runtime resolution so that tests can use Mox mocks while production uses
  real implementations.
  """

  # Defaults are module names (atoms) — no compile-time dependency on
  # Infrastructure modules. The actual modules are resolved at runtime via
  # Application.get_env, allowing tests to inject Mox mocks.
  @default_erm_gateway :"Elixir.Agents.Infrastructure.Gateways.ErmGateway"
  @default_identity_module :"Elixir.Identity"
  @default_jarga_gateway :"Elixir.Agents.Infrastructure.Gateways.JargaGateway"

  @doc "Returns the configured ERM gateway module."
  @spec erm_gateway() :: module()
  def erm_gateway do
    Application.get_env(:agents, :erm_gateway, @default_erm_gateway)
  end

  @doc "Returns the configured Identity module."
  @spec identity_module() :: module()
  def identity_module do
    Application.get_env(:agents, :identity_module, @default_identity_module)
  end

  @doc "Returns the configured Jarga gateway module."
  @spec jarga_gateway() :: module()
  def jarga_gateway do
    Application.get_env(:agents, :jarga_gateway, @default_jarga_gateway)
  end
end
