defmodule WebhooksApi.InboundLogController do
  use WebhooksApi, :controller

  def index(conn, %{"workspace_slug" => workspace_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.list_inbound_logs(user, api_key, workspace_slug) do
      {:ok, logs} ->
        conn |> put_status(:ok) |> render(:index, logs: logs)

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end
end
