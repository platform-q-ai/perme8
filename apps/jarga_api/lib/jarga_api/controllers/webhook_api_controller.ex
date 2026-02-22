defmodule JargaApi.WebhookApiController do
  @moduledoc """
  Controller for outbound Webhook Subscription API endpoints.

  Handles CRUD operations for webhook subscriptions scoped to a workspace.
  All endpoints require Bearer token authentication via ApiAuthPlug.

  ## Endpoints

    * `POST /api/workspaces/:workspace_slug/webhooks` - Create a subscription
    * `GET /api/workspaces/:workspace_slug/webhooks` - List subscriptions
    * `GET /api/workspaces/:workspace_slug/webhooks/:id` - Get subscription details
    * `PATCH /api/workspaces/:workspace_slug/webhooks/:id` - Update a subscription
    * `DELETE /api/workspaces/:workspace_slug/webhooks/:id` - Delete a subscription
  """

  use JargaApi, :controller

  alias JargaApi.Accounts.Domain.ApiKeyScope
  alias Jarga.Workspaces
  alias Jarga.Webhooks

  def create(conn, %{"workspace_slug" => workspace_slug} = params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      attrs = webhook_attrs(params)

      case Webhooks.create_subscription(user, workspace.id, attrs) do
        {:ok, subscription} ->
          conn
          |> put_status(:created)
          |> render(:created, subscription: subscription)

        {:error, :forbidden} ->
          forbidden(conn)

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:validation_error, changeset: changeset)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  def index(conn, %{"workspace_slug" => workspace_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.list_subscriptions(user, workspace.id) do
        {:ok, subscriptions} ->
          render(conn, :index, subscriptions: subscriptions)

        {:error, :forbidden} ->
          forbidden(conn)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  def show(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.get_subscription(user, workspace.id, id) do
        {:ok, subscription} ->
          render(conn, :show, subscription: subscription)

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

  def update(conn, %{"workspace_slug" => workspace_slug, "id" => id} = params) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      attrs = webhook_attrs(params)

      case Webhooks.update_subscription(user, workspace.id, id, attrs) do
        {:ok, subscription} ->
          render(conn, :show, subscription: subscription)

        {:error, :not_found} ->
          not_found(conn)

        {:error, :forbidden} ->
          forbidden(conn)

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:validation_error, changeset: changeset)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  def delete(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.delete_subscription(user, workspace.id, id) do
        {:ok, subscription} ->
          render(conn, :deleted, subscription: subscription)

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

  # Private helpers

  defp check_api_key_scope(api_key, workspace_slug) do
    if ApiKeyScope.includes?(api_key, workspace_slug), do: :ok, else: {:error, :forbidden}
  end

  @allowed_attrs ~w(url event_types is_active)

  defp webhook_attrs(params) do
    params
    |> Map.take(@allowed_attrs)
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
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
