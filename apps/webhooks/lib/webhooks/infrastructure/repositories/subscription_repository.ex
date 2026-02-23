defmodule Webhooks.Infrastructure.Repositories.SubscriptionRepository do
  @moduledoc """
  Repository for outbound webhook subscription data access.

  Implements the SubscriptionRepositoryBehaviour, converting between
  Ecto schemas and domain entities.
  """

  @behaviour Webhooks.Application.Behaviours.SubscriptionRepositoryBehaviour

  alias Webhooks.Infrastructure.Schemas.SubscriptionSchema
  alias Webhooks.Infrastructure.Queries.SubscriptionQueries

  @default_repo Webhooks.Repo

  @impl true
  def insert(attrs, repo \\ @default_repo) do
    %SubscriptionSchema{}
    |> SubscriptionSchema.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, SubscriptionSchema.to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def update(subscription_id, workspace_id, attrs, repo \\ @default_repo) do
    query =
      SubscriptionSchema
      |> SubscriptionQueries.by_id_and_workspace(subscription_id, workspace_id)

    case repo.one(query) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> SubscriptionSchema.update_changeset(attrs)
        |> repo.update()
        |> case do
          {:ok, updated} -> {:ok, SubscriptionSchema.to_entity(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def delete(subscription_id, workspace_id, repo \\ @default_repo) do
    query =
      SubscriptionSchema
      |> SubscriptionQueries.by_id_and_workspace(subscription_id, workspace_id)

    case repo.one(query) do
      nil ->
        {:error, :not_found}

      schema ->
        case repo.delete(schema) do
          {:ok, deleted} -> {:ok, SubscriptionSchema.to_entity(deleted)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def get_by_id(subscription_id, workspace_id, repo \\ @default_repo) do
    query =
      if workspace_id do
        SubscriptionSchema
        |> SubscriptionQueries.by_id_and_workspace(subscription_id, workspace_id)
      else
        SubscriptionSchema
        |> SubscriptionQueries.by_id(subscription_id)
      end

    case repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, SubscriptionSchema.to_entity(schema)}
    end
  end

  @impl true
  def list_for_workspace(workspace_id, repo \\ @default_repo) do
    results =
      SubscriptionSchema
      |> SubscriptionQueries.for_workspace(workspace_id)
      |> repo.all()
      |> Enum.map(&SubscriptionSchema.to_entity/1)

    {:ok, results}
  end

  @impl true
  def list_active_for_event_type(workspace_id, event_type, repo \\ @default_repo) do
    results =
      SubscriptionSchema
      |> SubscriptionQueries.for_workspace(workspace_id)
      |> SubscriptionQueries.active()
      |> SubscriptionQueries.matching_event_type(event_type)
      |> repo.all()
      |> Enum.map(&SubscriptionSchema.to_entity/1)

    {:ok, results}
  end
end
