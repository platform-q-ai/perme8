defmodule Webhooks.Application.UseCases.ReceiveInboundWebhook do
  @moduledoc """
  Use case for receiving and processing inbound webhook requests.

  No user authorization required -- uses HMAC signature verification instead.

  Steps:
  1. Get inbound config for workspace
  2. Verify HMAC signature
  3. Record inbound log
  4. Return result
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.HmacPolicy

  @default_config_repository Webhooks.Infrastructure.Repositories.InboundWebhookConfigRepository
  @default_log_repository Webhooks.Infrastructure.Repositories.InboundLogRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      raw_body: raw_body,
      signature: signature,
      source_ip: source_ip
    } = params

    config_repository =
      Keyword.get(opts, :inbound_webhook_config_repository, @default_config_repository)

    log_repository =
      Keyword.get(opts, :inbound_log_repository, @default_log_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- validate_signature_present(signature),
         {:ok, config} <- get_config(workspace_id, config_repository, repo) do
      if HmacPolicy.valid_signature?(config.secret, raw_body, signature) do
        parsed_payload = parse_payload(raw_body)

        log_attrs = %{
          workspace_id: workspace_id,
          event_type: Map.get(parsed_payload, "event"),
          payload: parsed_payload,
          source_ip: source_ip,
          signature_valid: true,
          received_at: DateTime.utc_now()
        }

        log_repository.insert(log_attrs, repo)
      else
        # Record the failed attempt but return error
        log_attrs = %{
          workspace_id: workspace_id,
          payload: parse_payload(raw_body),
          source_ip: source_ip,
          signature_valid: false,
          received_at: DateTime.utc_now()
        }

        log_repository.insert(log_attrs, repo)
        {:error, :invalid_signature}
      end
    end
  end

  defp validate_signature_present(nil), do: {:error, :missing_signature}
  defp validate_signature_present(""), do: {:error, :missing_signature}
  defp validate_signature_present(_signature), do: :ok

  defp get_config(workspace_id, config_repository, repo) do
    case config_repository.get_by_workspace_id(workspace_id, repo) do
      {:ok, config} -> {:ok, config}
      {:error, :not_found} -> {:error, :not_configured}
    end
  end

  defp parse_payload(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{"raw" => raw_body}
    end
  end
end
