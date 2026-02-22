defmodule Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository do
  @moduledoc """
  Repository for webhook subscription data access.

  Converts between infrastructure schemas and domain entities.
  """

  @behaviour Jarga.Webhooks.Application.Behaviours.WebhookRepositoryBehaviour

  alias Identity.Repo, as: Repo
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription
  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchema
  alias Jarga.Webhooks.Infrastructure.Queries.WebhookQueries

  @impl true
  def insert(attrs, _opts \\ []) do
    %WebhookSubscriptionSchema{}
    |> WebhookSubscriptionSchema.changeset(attrs)
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
      |> WebhookSubscriptionSchema.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, schema} -> {:ok, to_domain(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @impl true
  def delete(entity_or_schema, _opts \\ []) do
    with {:ok, schema} <- ensure_schema(entity_or_schema) do
      schema
      |> Repo.delete()
      |> case do
        {:ok, schema} -> {:ok, to_domain(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp ensure_schema(%WebhookSubscriptionSchema{} = schema), do: {:ok, schema}

  defp ensure_schema(%WebhookSubscription{id: id}) when not is_nil(id) do
    case Repo.get(WebhookSubscriptionSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  defp ensure_schema(%{id: id}) when not is_nil(id) do
    case Repo.get(WebhookSubscriptionSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  @impl true
  def get(id, _opts \\ []) do
    case Repo.get(WebhookSubscriptionSchema, id) do
      nil -> nil
      schema -> to_domain(schema)
    end
  end

  @impl true
  def list_for_workspace(workspace_id, _opts \\ []) do
    WebhookQueries.for_workspace(workspace_id)
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @impl true
  def list_active_for_event(workspace_id, event_type, _opts \\ []) do
    WebhookQueries.active_for_event(workspace_id, event_type)
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @doc "Converts a schema to a domain entity."
  def to_domain(%WebhookSubscriptionSchema{} = schema) do
    %WebhookSubscription{
      id: schema.id,
      url: schema.url,
      secret: schema.secret,
      event_types: schema.event_types || [],
      is_active: schema.is_active,
      workspace_id: schema.workspace_id,
      created_by_id: schema.created_by_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
