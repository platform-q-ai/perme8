defmodule Agents.Sessions.Infrastructure.SdkEventDebouncer do
  @moduledoc """
  Debounces high-frequency domain events to avoid excessive PubSub broadcasts.

  Uses a simple time-window approach: for debounced event types, the event is
  only emitted if enough time has passed since the last emission of that type.

  State-changing events are never debounced.
  """

  @default_interval_ms 500
  @debounced_types MapSet.new([:message_part_updated])

  @type t :: %{optional(atom()) => integer()}

  @doc "Creates a new empty debouncer state."
  @spec new() :: t()
  def new, do: %{}

  @doc "Returns true if the given event type is subject to debouncing."
  @spec debounced_type?(atom()) :: boolean()
  def debounced_type?(type), do: MapSet.member?(@debounced_types, type)

  @doc "Checks if an event should be emitted based on the debounce window."
  @spec should_emit?(t(), atom(), keyword()) :: boolean()
  def should_emit?(debouncer, type, opts \\ []) do
    if debounced_type?(type) do
      interval = Keyword.get(opts, :interval, @default_interval_ms)
      now = System.monotonic_time(:millisecond)

      case Map.get(debouncer, type) do
        nil -> true
        last_at -> now - last_at >= interval
      end
    else
      true
    end
  end

  @doc "Checks if an event should be emitted and records the emission if so."
  @spec check_and_record(t(), atom(), keyword()) :: {boolean(), t()}
  def check_and_record(debouncer, type, opts \\ []) do
    if should_emit?(debouncer, type, opts) do
      now = System.monotonic_time(:millisecond)
      {true, Map.put(debouncer, type, now)}
    else
      {false, debouncer}
    end
  end
end
