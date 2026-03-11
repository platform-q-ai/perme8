defmodule Agents.Sessions.Infrastructure.SdkEventHandler do
  @moduledoc """
  Infrastructure entry point for SDK-event-to-Session processing.

  Receives raw SDK events, applies the `SdkEventPolicy` to compute state
  transitions and domain events, then emits the domain events via EventBus.

  This is the single bridge between the GenServer world (TaskRunner) and
  the pure domain model. No Repo calls.
  """

  alias Agents.Sessions.Domain.Policies.{SdkEventPolicy, SdkEventTypes}

  require Logger

  @default_event_bus Perme8.Events.EventBus

  @doc """
  Handles a raw SDK event for a given Session.

  Returns `{:ok, updated_session}` on success or `{:skip, reason}` if
  the event was not processed.

  ## Options

  - `:event_bus` — module implementing `emit_all/2` (default: `Perme8.Events.EventBus`)
  """
  @spec handle(struct(), map(), keyword()) :: {:ok, struct()} | {:skip, atom()}
  def handle(session, sdk_event, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_type = Map.get(sdk_event, "type", "unknown")

    if SdkEventTypes.handled?(event_type) do
      case SdkEventPolicy.apply_event(session, sdk_event) do
        {:ok, updated_session, []} ->
          {:ok, updated_session}

        {:ok, updated_session, domain_events} ->
          :ok = event_bus.emit_all(domain_events)
          {:ok, updated_session}

        {:skip, reason} ->
          Logger.debug(
            "SdkEventHandler: skipped event #{event_type} for task #{session.task_id}: #{reason}"
          )

          {:skip, reason}
      end
    else
      Logger.debug(
        "SdkEventHandler: not relevant event #{event_type} for task #{session.task_id}"
      )

      {:skip, :not_relevant}
    end
  end
end
