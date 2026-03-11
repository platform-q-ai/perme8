defmodule Agents.Sessions.Infrastructure.SdkEventHandler do
  @moduledoc """
  Infrastructure entry point for SDK-event-to-Session processing.

  Receives raw SDK events, applies the `SdkEventPolicy` to compute state
  transitions and domain events, then emits the domain events via EventBus.

  This is the single bridge between the GenServer world (TaskRunner) and
  the pure domain model. No Repo calls.
  """

  alias Agents.Sessions.Domain.Entities.Session
  alias Agents.Sessions.Domain.Policies.SdkEventPolicy

  require Logger

  @default_event_bus Perme8.Events.EventBus

  @doc """
  Handles a raw SDK event for a given Session.

  Returns `{:ok, updated_session}` on success or `{:skip, reason}` if
  the event was not processed.

  ## Options

  - `:event_bus` — module implementing `emit_all/2` (default: `Perme8.Events.EventBus`)
  """
  @spec handle(Session.t(), map(), keyword()) :: {:ok, Session.t()} | {:skip, atom()}
  def handle(session, sdk_event, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    case SdkEventPolicy.apply_event(session, sdk_event) do
      {:ok, updated_session, []} ->
        {:ok, updated_session}

      {:ok, updated_session, domain_events} ->
        case event_bus.emit_all(domain_events) do
          :ok ->
            :ok

          error ->
            Logger.warning(
              "SdkEventHandler: emit_all failed for task #{session.task_id}: #{inspect(error)}"
            )
        end

        {:ok, updated_session}

      {:skip, reason} ->
        {:skip, reason}
    end
  end
end
