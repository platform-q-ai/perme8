defmodule KnowledgeMcp.Application.GatewayConfig do
  @moduledoc """
  Runtime gateway and service configuration.

  Resolves which `ErmGatewayBehaviour` and `IdentityBehaviour` implementations
  to use. Uses `Application.get_env/3` for runtime resolution so that tests
  can use Mox mocks while production uses real implementations.

  Each use case should call these functions (or accept overrides via `opts`)
  rather than using `Application.get_env` directly.
  """

  @default_erm_gateway KnowledgeMcp.Infrastructure.ErmGateway
  @default_identity_module Identity

  @doc "Returns the configured ERM gateway module."
  @spec erm_gateway() :: module()
  def erm_gateway do
    Application.get_env(:knowledge_mcp, :erm_gateway, @default_erm_gateway)
  end

  @doc "Returns the configured Identity module."
  @spec identity_module() :: module()
  def identity_module do
    Application.get_env(:knowledge_mcp, :identity_module, @default_identity_module)
  end
end
