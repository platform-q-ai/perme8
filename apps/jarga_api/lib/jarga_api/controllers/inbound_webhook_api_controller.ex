defmodule JargaApi.InboundWebhookApiController do
  @moduledoc """
  Controller for Inbound Webhook API endpoints.

  Handles receiving external webhooks with HMAC signature verification
  and viewing audit logs.

  ## Endpoints

    * `POST /api/workspaces/:workspace_slug/webhooks/inbound` - Receive inbound webhook (signature auth)
    * `GET /api/workspaces/:workspace_slug/webhooks/inbound/logs` - View audit logs (bearer token auth)
  """

  use JargaApi, :controller

  alias JargaApi.Accounts.Domain.ApiKeyScope
  alias Jarga.Workspaces
  alias Jarga.Webhooks

  @doc """
  Receives an inbound webhook payload.

  This endpoint does NOT use Bearer token auth. Instead, it verifies
  the payload using HMAC signature from the X-Webhook-Signature header.

  The workspace secret is provided via the X-Webhook-Secret header
  (in production this would come from workspace configuration).
  """
  def receive(conn, %{"workspace_slug" => workspace_slug} = params) do
    signature = get_signature(conn)
    workspace_secret = get_workspace_secret(conn)
    source_ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    # Re-encode the parsed body (minus the path param) as the raw body for HMAC
    # In production, use RawBodyReader to capture the actual raw bytes
    payload_params = Map.drop(params, ["workspace_slug"])
    raw_body = Jason.encode!(payload_params)

    # Resolve workspace from slug to get workspace_id
    # For inbound webhooks, there's no authenticated user — use direct lookup
    case resolve_workspace_id(workspace_slug) do
      {:ok, workspace_id} ->
        webhook_params = %{
          workspace_id: workspace_id,
          raw_body: raw_body,
          signature: signature,
          source_ip: source_ip,
          workspace_secret: workspace_secret
        }

        case Webhooks.process_inbound_webhook(webhook_params) do
          {:ok, _inbound_webhook} ->
            render(conn, :received)

          {:error, :invalid_signature} ->
            conn
            |> put_status(:unauthorized)
            |> render(:error, message: "Invalid signature")

          {:error, :missing_signature} ->
            conn
            |> put_status(:unauthorized)
            |> render(:error, message: "Missing signature")

          {:error, :invalid_payload} ->
            conn
            |> put_status(:bad_request)
            |> render(:error, message: "Invalid payload")
        end

      {:error, :not_found} ->
        not_found(conn, "Workspace not found")
    end
  end

  @doc """
  Lists inbound webhook audit logs for a workspace.

  Requires Bearer token authentication with admin access.
  """
  def logs(conn, %{"workspace_slug" => workspace_slug}) do
    user = conn.assigns.current_user
    api_key = conn.assigns.api_key

    with :ok <- check_api_key_scope(api_key, workspace_slug),
         {:ok, workspace, _member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      case Webhooks.list_inbound_logs(user, workspace.id) do
        {:ok, logs} ->
          render(conn, :logs, logs: logs)

        {:error, :forbidden} ->
          forbidden(conn)
      end
    else
      {:error, :forbidden} -> forbidden(conn)
      {:error, :workspace_not_found} -> not_found(conn, "Workspace not found")
    end
  end

  defp resolve_workspace_id(slug) do
    import Ecto.Query
    query = from(w in "workspaces", where: w.slug == ^slug, select: type(w.id, :binary_id))

    case Identity.Repo.one(query) do
      nil -> {:error, :not_found}
      id -> {:ok, id}
    end
  end

  defp get_signature(conn) do
    case Plug.Conn.get_req_header(conn, "x-webhook-signature") do
      [sig] when byte_size(sig) > 0 -> sig
      _ -> nil
    end
  end

  defp get_workspace_secret(conn) do
    case Plug.Conn.get_req_header(conn, "x-webhook-secret") do
      [secret] when byte_size(secret) > 0 -> secret
      _ -> nil
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

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> render(:error, message: message)
  end
end
