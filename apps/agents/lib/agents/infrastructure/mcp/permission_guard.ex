defmodule Agents.Infrastructure.Mcp.PermissionGuard do
  @moduledoc "Checks MCP tool permissions against the API key's permission scopes."

  alias Agents.Application.GatewayConfig

  @spec check_permission(struct(), String.t(), keyword()) :: :ok | {:error, String.t()}
  def check_permission(frame, tool_name, opts \\ []) do
    identity_module = Keyword.get(opts, :identity_module, GatewayConfig.identity_module())
    api_key = frame.assigns[:api_key]
    required_scope = "mcp:#{tool_name}"

    if identity_module.api_key_has_permission?(api_key, required_scope) do
      :ok
    else
      {:error, required_scope}
    end
  end
end
