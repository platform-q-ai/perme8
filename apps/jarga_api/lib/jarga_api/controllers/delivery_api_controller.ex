defmodule JargaApi.DeliveryApiController do
  @moduledoc """
  Controller for Webhook Delivery log API endpoints.

  Handles read operations for delivery attempts scoped to a webhook subscription.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  ## Endpoints

    * `GET /api/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries` - List deliveries
    * `GET /api/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries/:id` - Get delivery details
  """

  use JargaApi, :controller

  alias JargaApi.Accounts.Domain.ApiKeyScope
  alias Jarga.Workspaces
  alias Jarga.Webhooks

  def index(conn, %{"workspace_slug" => workspace_slug, "webhook_id" => webhook_id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.list_deliveries(user, workspace.id, webhook_id) do
        {:ok, deliveries} ->
          render(conn, :index, deliveries: deliveries)

        {:error, :forbidden} ->
          forbidden(conn)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  def show(conn, %{
        "workspace_slug" => workspace_slug,
        "webhook_id" => _webhook_id,
        "id" => delivery_id
      }) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.get_delivery(user, workspace.id, delivery_id) do
        {:ok, delivery} ->
          render(conn, :show, delivery: delivery)

        {:error, :not_found} ->
          not_found(conn)

        {:error, :forbidden} ->
          forbidden(conn)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  defp check_api_key_scope(api_key, workspace_slug) do
    if ApiKeyScope.includes?(api_key, workspace_slug), do: :ok, else: {:error, :forbidden}
  end

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> render(:error, message: "Insufficient permissions")
  end

  defp not_found(conn, message \\ "Not found") do
    conn
    |> put_status(:not_found)
    |> render(:error, message: message)
  end
end
