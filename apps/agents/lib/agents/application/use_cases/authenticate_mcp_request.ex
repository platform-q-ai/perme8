defmodule Agents.Application.UseCases.AuthenticateMcpRequest do
  @moduledoc """
  Verifies an API key and resolves workspace context.

  Calls Identity.verify_api_key/1 (injected via opts) and extracts
  the workspace_id from the API key's workspace_access list.
  The workspace slug is resolved to a UUID via Identity.resolve_workspace_id/1
  so that downstream services (e.g., the ERM) receive a proper UUID.
  """

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def execute(token, opts \\ []) do
    identity_module = Keyword.get(opts, :identity_module, GatewayConfig.identity_module())

    case identity_module.verify_api_key(token) do
      {:ok, api_key} ->
        resolve_workspace(api_key, identity_module)

      {:error, _reason} ->
        {:error, :unauthorized}
    end
  end

  defp resolve_workspace(%{workspace_access: [workspace_slug | _]} = api_key, identity_module) do
    case identity_module.resolve_workspace_id(workspace_slug) do
      {:ok, workspace_id} ->
        {:ok, %{workspace_id: workspace_id, user_id: api_key.user_id}}

      {:error, :not_found} ->
        {:error, :workspace_not_found}
    end
  end

  defp resolve_workspace(%{workspace_access: []}, _identity_module) do
    {:error, :no_workspace_access}
  end

  defp resolve_workspace(%{workspace_access: nil}, _identity_module) do
    {:error, :no_workspace_access}
  end
end
