defmodule Webhooks.Infrastructure.Repositories.DeliveryRepository do
  @moduledoc """
  Repository for webhook delivery data access.

  Implements the DeliveryRepositoryBehaviour, converting between
  Ecto schemas and domain entities.
  """

  @behaviour Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Webhooks.Infrastructure.Schemas.DeliverySchema
  alias Webhooks.Infrastructure.Queries.DeliveryQueries

  @default_repo WebhooksApi.Repo

  @impl true
  def insert(attrs, repo \\ @default_repo) do
    %DeliverySchema{}
    |> DeliverySchema.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, DeliverySchema.to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def get_by_id(delivery_id, _workspace_id, repo \\ @default_repo) do
    case repo.get(DeliverySchema, delivery_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, DeliverySchema.to_entity(schema)}
    end
  end

  @impl true
  def list_for_subscription(subscription_id, repo \\ @default_repo) do
    results =
      DeliverySchema
      |> DeliveryQueries.for_subscription(subscription_id)
      |> DeliveryQueries.ordered()
      |> repo.all()
      |> Enum.map(&DeliverySchema.to_entity/1)

    {:ok, results}
  end

  @impl true
  def update_status(delivery_id, attrs, repo \\ @default_repo) do
    case repo.get(DeliverySchema, delivery_id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> DeliverySchema.changeset(attrs)
        |> repo.update()
        |> case do
          {:ok, updated} -> {:ok, DeliverySchema.to_entity(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def list_pending_retries(repo \\ @default_repo) do
    results =
      DeliverySchema
      |> DeliveryQueries.pending_retries()
      |> repo.all()
      |> Enum.map(&DeliverySchema.to_entity/1)

    {:ok, results}
  end
end
