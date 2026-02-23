defmodule WebhooksApi.DeliveryController do
  use WebhooksApi, :controller

  def index(conn, %{"workspace_slug" => workspace_slug, "subscription_id" => subscription_id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.list_deliveries(user, api_key, workspace_slug, subscription_id) do
      {:ok, deliveries} ->
        conn |> put_status(:ok) |> render(:index, deliveries: deliveries)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Subscription not found")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  def show(conn, %{
        "workspace_slug" => workspace_slug,
        "subscription_id" => _subscription_id,
        "id" => id
      }) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.get_delivery(user, api_key, workspace_slug, id) do
      {:ok, delivery} ->
        conn |> put_status(:ok) |> render(:show, delivery: delivery)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Delivery not found")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end
end
