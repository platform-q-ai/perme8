defmodule WebhooksApi.InboundWebhookController do
  use WebhooksApi, :controller

  def receive(conn, %{"workspace_slug" => workspace_slug}) do
    raw_body = conn.private[:raw_body] || ""
    signature = get_signature(conn)
    source_ip = get_source_ip(conn)

    case Webhooks.receive_inbound_webhook(workspace_slug, raw_body, signature, source_ip) do
      {:ok, _log} ->
        conn |> put_status(:ok) |> render(:received)

      {:error, :invalid_signature} ->
        conn |> put_status(:unauthorized) |> render(:error, message: "Invalid signature")

      {:error, :missing_signature} ->
        conn |> put_status(:unauthorized) |> render(:error, message: "Missing signature")

      {:error, :not_configured} ->
        conn |> put_status(:not_found) |> render(:error, message: "Webhook not configured")

      {:error, :workspace_not_found} ->
        conn |> put_status(:not_found) |> render(:error, message: "Workspace not found")
    end
  end

  defp get_signature(conn) do
    case get_req_header(conn, "x-webhook-signature") do
      [sig | _] -> sig
      [] -> nil
    end
  end

  defp get_source_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end
end
