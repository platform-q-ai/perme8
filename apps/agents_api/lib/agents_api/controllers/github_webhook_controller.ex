defmodule AgentsApi.GithubWebhookController do
  @moduledoc """
  Receives GitHub App webhook events for agent automation.
  """

  use AgentsApi, :controller

  alias AgentsApi.GithubWebhookConfig

  def receive(conn, payload) when is_map(payload) do
    raw_body = conn.private[:raw_body] || ""

    with :ok <- verify_signature(conn, raw_body),
         {:ok, event} <- fetch_event(conn) do
      case processor_module().process(event, payload) do
        {:ok, {:queued, details}} ->
          conn
          |> put_status(:accepted)
          |> render(:queued, details: details)

        {:ok, :ignored} ->
          conn
          |> put_status(:accepted)
          |> render(:ignored)

        {:error, :automation_disabled} ->
          conn
          |> put_status(:service_unavailable)
          |> render(:error, message: "Webhook automation is disabled")

        {:error, :missing_automation_user_id} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, message: "Missing GITHUB_WEBHOOK_AUTOMATION_USER_ID")

        {:error, :invalid_payload} ->
          conn
          |> put_status(:bad_request)
          |> render(:error, message: "Invalid payload")

        {:error, {:task_creation_failed, reason}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, message: "Failed to queue task: #{inspect(reason)}")

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, message: "Webhook processing failed: #{inspect(reason)}")
      end
    else
      {:error, :missing_webhook_secret} ->
        conn
        |> put_status(:service_unavailable)
        |> render(:error, message: "Missing GITHUB_WEBHOOK_SECRET")

      {:error, :missing_signature} ->
        conn
        |> put_status(:unauthorized)
        |> render(:error, message: "Missing X-Hub-Signature-256 header")

      {:error, :invalid_signature} ->
        conn
        |> put_status(:unauthorized)
        |> render(:error, message: "Invalid webhook signature")

      {:error, :missing_event} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, message: "Missing X-GitHub-Event header")
    end
  end

  defp fetch_event(conn) do
    case get_req_header(conn, "x-github-event") do
      [event | _] when is_binary(event) and event != "" -> {:ok, event}
      _ -> {:error, :missing_event}
    end
  end

  defp verify_signature(conn, raw_body) do
    with {:ok, secret} <- fetch_secret(),
         {:ok, signature} <- fetch_signature(conn),
         :ok <- valid_signature(secret, raw_body, signature) do
      :ok
    end
  end

  defp fetch_secret do
    case GithubWebhookConfig.secret() do
      secret when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> {:error, :missing_webhook_secret}
    end
  end

  defp fetch_signature(conn) do
    case get_req_header(conn, "x-hub-signature-256") do
      [signature | _] when is_binary(signature) and signature != "" -> {:ok, signature}
      _ -> {:error, :missing_signature}
    end
  end

  defp valid_signature(secret, raw_body, signature_header) do
    expected =
      "sha256=" <>
        (:crypto.mac(:hmac, :sha256, secret, raw_body)
         |> Base.encode16(case: :lower))

    if Plug.Crypto.secure_compare(signature_header, expected) do
      :ok
    else
      {:error, :invalid_signature}
    end
  rescue
    ArgumentError -> {:error, :invalid_signature}
  end

  defp processor_module do
    Application.get_env(:agents_api, :github_webhook_processor, __MODULE__.Processor)
  end

  defmodule Processor do
    @moduledoc false

    def process(event, payload), do: Agents.process_github_webhook(event, payload)
  end
end
