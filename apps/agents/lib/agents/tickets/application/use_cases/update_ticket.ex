defmodule Agents.Tickets.Application.UseCases.UpdateTicket do
  @moduledoc """
  Use case for updating a ticket's fields locally.

  Updates the specified fields on the ticket, sets `sync_state` to
  `"pending_push"`, emits a `TicketUpdated` domain event, and broadcasts
  a ticket refresh so the UI updates immediately.

  The actual push to GitHub happens asynchronously via an event handler.
  """

  alias Agents.Tickets.Domain.Events.TicketUpdated

  @default_event_bus Perme8.Events.EventBus
  @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @updatable_fields ~w(title body labels state priority size)a

  @doc """
  Updates a ticket identified by number.

  ## Parameters
  - `number` - The ticket number
  - `attrs` - Map of fields to update (title, body, labels, state, priority, size)
  - `opts` - Keyword list with:
    - `:actor_id` - (required) The user making the update
    - `:event_bus` - Event bus module (default: EventBus)
    - `:ticket_repo` - Repository module (default: ProjectTicketRepository)

  ## Returns
  - `{:ok, schema}` on success
  - `{:error, :no_changes}` when attrs map has no updatable fields
  - `{:error, :not_found}` when ticket doesn't exist
  - `{:error, changeset}` on validation failure
  """
  @spec execute(integer(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def execute(number, attrs, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    filtered_attrs = filter_attrs(attrs)

    with :ok <- validate_not_empty(filtered_attrs),
         update_attrs = Map.put(filtered_attrs, :sync_state, "pending_push"),
         {:ok, schema} <- ticket_repo.update_fields(number, update_attrs) do
      emit_event(schema, filtered_attrs, actor_id, event_bus)
      broadcast_tickets_refresh()
      {:ok, schema}
    end
  end

  defp filter_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take(@updatable_fields)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp validate_not_empty(attrs) when map_size(attrs) == 0, do: {:error, :no_changes}
  defp validate_not_empty(_attrs), do: :ok

  defp emit_event(schema, changes, actor_id, event_bus) do
    event_bus.emit(
      TicketUpdated.new(%{
        aggregate_id: to_string(schema.id),
        actor_id: actor_id,
        ticket_id: schema.id,
        number: schema.number,
        changes: changes
      })
    )
  end

  defp broadcast_tickets_refresh do
    Phoenix.PubSub.broadcast(
      @default_pubsub,
      @tickets_topic,
      {:tickets_synced, []}
    )
  end
end
