defmodule Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository do
  @moduledoc """
  Repository for webhook delivery data access.

  Converts between infrastructure schemas and domain entities.
  """

  @behaviour Jarga.Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour

  alias Identity.Repo, as: Repo
  alias Jarga.Webhooks.Domain.Entities.WebhookDelivery
  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema
  alias Jarga.Webhooks.Infrastructure.Queries.DeliveryQueries

  @impl true
  def insert(attrs, _opts \\ []) do
    %WebhookDeliverySchema{}
    |> WebhookDeliverySchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def update(entity_or_schema, attrs, _opts \\ []) do
    with {:ok, schema} <- ensure_schema(entity_or_schema) do
      schema
      |> WebhookDeliverySchema.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, schema} -> {:ok, to_domain(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp ensure_schema(%WebhookDeliverySchema{} = schema), do: {:ok, schema}

  defp ensure_schema(%WebhookDelivery{id: id}) when not is_nil(id) do
    case Repo.get(WebhookDeliverySchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  defp ensure_schema(%{id: id}) when not is_nil(id) do
    case Repo.get(WebhookDeliverySchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  @impl true
  def get(id, _opts \\ []) do
    case Repo.get(WebhookDeliverySchema, id) do
      nil -> nil
      schema -> to_domain(schema)
    end
  end

  @impl true
  def list_for_subscription(subscription_id, _opts \\ []) do
    DeliveryQueries.for_subscription(subscription_id)
    |> DeliveryQueries.ordered()
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @impl true
  def list_pending_retries(_opts \\ []) do
    DeliveryQueries.pending_retries()
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @doc "Converts a schema to a domain entity."
  def to_domain(%WebhookDeliverySchema{} = schema) do
    %WebhookDelivery{
      id: schema.id,
      webhook_subscription_id: schema.webhook_subscription_id,
      event_type: schema.event_type,
      payload: schema.payload,
      status: schema.status,
      response_code: schema.response_code,
      response_body: schema.response_body,
      attempts: schema.attempts,
      max_attempts: schema.max_attempts,
      next_retry_at: schema.next_retry_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
