defmodule Agents.Application.UseCases.AuthenticateMcpRequest do
  @moduledoc """
  Verifies an API key and resolves workspace context.

  Calls Identity.verify_api_key/1 (injected via opts) and extracts
  the workspace_id from the API key's workspace_access list.
  """

  alias Agents.Application.GatewayConfig

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def execute(token, opts \\ []) do
    identity_module = Keyword.get(opts, :identity_module, GatewayConfig.identity_module())

    case identity_module.verify_api_key(token) do
      {:ok, api_key} ->
        resolve_workspace(api_key)

      {:error, _reason} ->
        {:error, :unauthorized}
    end
  end

  defp resolve_workspace(%{workspace_access: [workspace_id | _]} = api_key) do
    {:ok, %{workspace_id: workspace_id, user_id: api_key.user_id}}
  end

  defp resolve_workspace(%{workspace_access: []}) do
    {:error, :no_workspace_access}
  end

  defp resolve_workspace(%{workspace_access: nil}) do
    {:error, :no_workspace_access}
  end
end
