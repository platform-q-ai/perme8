defmodule WebhooksApi.SubscriptionController do
  use WebhooksApi, :controller

  def create(conn, %{"workspace_slug" => workspace_slug} = params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key
    attrs = Map.take(params, ["url", "event_types"])

    case Webhooks.create_subscription(user, api_key, workspace_slug, attrs) do
      {:ok, subscription} ->
        conn |> put_status(:created) |> render(:created, subscription: subscription)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  def index(conn, %{"workspace_slug" => workspace_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.list_subscriptions(user, api_key, workspace_slug) do
      {:ok, subscriptions} ->
        conn |> put_status(:ok) |> render(:index, subscriptions: subscriptions)

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  def show(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.get_subscription(user, api_key, workspace_slug, id) do
      {:ok, subscription} ->
        conn |> put_status(:ok) |> render(:show, subscription: subscription)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Subscription not found")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  def update(conn, %{"workspace_slug" => workspace_slug, "id" => id} = params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key
    attrs = Map.take(params, ["url", "event_types", "is_active"])

    case Webhooks.update_subscription(user, api_key, workspace_slug, id, attrs) do
      {:ok, subscription} ->
        conn |> put_status(:ok) |> render(:show, subscription: subscription)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Subscription not found")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  def delete(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    case Webhooks.delete_subscription(user, api_key, workspace_slug, id) do
      {:ok, _} ->
        conn |> put_status(:ok) |> render(:deleted)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Subscription not found")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> render(:error, message: "Insufficient permissions")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end
end
