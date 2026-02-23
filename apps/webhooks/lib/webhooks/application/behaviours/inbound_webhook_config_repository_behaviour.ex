defmodule Webhooks.Application.Behaviours.InboundWebhookConfigRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the inbound webhook config repository contract.

  Implementations handle retrieval of inbound webhook configurations.
  """

  alias Webhooks.Domain.Entities.InboundWebhookConfig

  @type repo :: module()

  @callback get_by_workspace_id(workspace_id :: String.t(), repo) ::
              {:ok, InboundWebhookConfig.t()} | {:error, :not_found}
end
