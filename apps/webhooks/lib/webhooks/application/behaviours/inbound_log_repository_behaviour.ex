defmodule Webhooks.Application.Behaviours.InboundLogRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the inbound log repository contract.

  Implementations handle persistence of inbound webhook log entries.
  """

  alias Webhooks.Domain.Entities.InboundLog

  @type repo :: module()

  @callback insert(attrs :: map(), repo) ::
              {:ok, InboundLog.t()} | {:error, Ecto.Changeset.t()}

  @callback list_for_workspace(workspace_id :: String.t(), repo) ::
              {:ok, [InboundLog.t()]}
end
