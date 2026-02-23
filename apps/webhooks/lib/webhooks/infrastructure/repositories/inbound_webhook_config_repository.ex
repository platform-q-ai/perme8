defmodule Webhooks.Infrastructure.Repositories.InboundWebhookConfigRepository do
  @moduledoc """
  Repository for inbound webhook configuration data access.

  Implements the InboundWebhookConfigRepositoryBehaviour.
  """

  @behaviour Webhooks.Application.Behaviours.InboundWebhookConfigRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema

  @default_repo Webhooks.Repo

  @impl true
  def get_by_workspace_id(workspace_id, repo \\ @default_repo) do
    query =
      from(c in InboundWebhookConfigSchema,
        where: c.workspace_id == ^workspace_id and c.is_active == true
      )

    case repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, InboundWebhookConfigSchema.to_entity(schema)}
    end
  end
end
