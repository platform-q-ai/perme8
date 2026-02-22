defmodule Jarga.Webhooks.Infrastructure.Repositories.InboundWebhookRepository do
  @moduledoc """
  Repository for inbound webhook data access.

  Converts between infrastructure schemas and domain entities.
  """

  @behaviour Jarga.Webhooks.Application.Behaviours.InboundWebhookRepositoryBehaviour

  alias Identity.Repo, as: Repo
  alias Jarga.Webhooks.Domain.Entities.InboundWebhook
  alias Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchema
  alias Jarga.Webhooks.Infrastructure.Queries.InboundWebhookQueries
  alias Jarga.Webhooks.Infrastructure.Queries.InboundWebhookConfigQueries

  @impl true
  def insert(attrs, _opts \\ []) do
    %InboundWebhookSchema{}
    |> InboundWebhookSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def list_for_workspace(workspace_id, _opts \\ []) do
    InboundWebhookQueries.for_workspace(workspace_id)
    |> InboundWebhookQueries.ordered()
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @impl true
  def get_inbound_secret(workspace_id, _opts \\ []) do
    case InboundWebhookConfigQueries.for_workspace(workspace_id) |> Repo.one() do
      nil -> {:error, :not_configured}
      config -> {:ok, config.inbound_secret}
    end
  end

  @doc "Converts a schema to a domain entity."
  def to_domain(%InboundWebhookSchema{} = schema) do
    %InboundWebhook{
      id: schema.id,
      workspace_id: schema.workspace_id,
      event_type: schema.event_type,
      payload: schema.payload,
      source_ip: schema.source_ip,
      signature_valid: schema.signature_valid,
      handler_result: schema.handler_result,
      received_at: schema.received_at,
      inserted_at: schema.inserted_at
    }
  end
end
