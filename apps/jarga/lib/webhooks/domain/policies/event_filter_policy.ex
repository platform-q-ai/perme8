defmodule Jarga.Webhooks.Domain.Policies.EventFilterPolicy do
  @moduledoc """
  Pure policy for matching events against subscription filters.

  Empty or nil event_types acts as a wildcard — matching ALL events.
  No I/O, no side effects.
  """

  @event_type_format ~r/^[a-z_]+\.[a-z_]+$/

  @doc """
  Checks if an event_type matches a subscription's event_types filter.

  Empty or nil event_types matches ALL events (wildcard behavior).
  """
  @spec matches?(String.t(), map()) :: boolean()
  def matches?(_event_type, %{event_types: nil}), do: true
  def matches?(_event_type, %{event_types: []}), do: true

  def matches?(event_type, %{event_types: event_types}) when is_list(event_types) do
    event_type in event_types
  end

  @doc """
  Validates that a list of event type strings follows the `"context.event_name"` format.

  Empty list is valid (wildcard).
  """
  @spec valid_event_types?([String.t()]) :: boolean()
  def valid_event_types?([]), do: true

  def valid_event_types?(event_types) when is_list(event_types) do
    Enum.all?(event_types, &valid_event_type?/1)
  end

  defp valid_event_type?(type) when is_binary(type) do
    Regex.match?(@event_type_format, type)
  end

  defp valid_event_type?(_), do: false
end
