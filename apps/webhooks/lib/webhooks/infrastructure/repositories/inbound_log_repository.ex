defmodule Webhooks.Infrastructure.Repositories.InboundLogRepository do
  @moduledoc """
  Repository for inbound webhook log data access.

  Implements the InboundLogRepositoryBehaviour, converting between
  Ecto schemas and domain entities.
  """

  @behaviour Webhooks.Application.Behaviours.InboundLogRepositoryBehaviour

  alias Webhooks.Infrastructure.Schemas.InboundLogSchema
  alias Webhooks.Infrastructure.Queries.InboundLogQueries

  @default_repo Webhooks.Repo
  @default_list_limit 100

  @impl true
  def insert(attrs, repo \\ @default_repo) do
    %InboundLogSchema{}
    |> InboundLogSchema.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, schema} -> {:ok, InboundLogSchema.to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def list_for_workspace(workspace_id, repo \\ @default_repo) do
    results =
      InboundLogSchema
      |> InboundLogQueries.for_workspace(workspace_id)
      |> InboundLogQueries.ordered()
      |> InboundLogQueries.limit(@default_list_limit)
      |> repo.all()
      |> Enum.map(&InboundLogSchema.to_entity/1)

    {:ok, results}
  end
end
