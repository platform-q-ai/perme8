defmodule Agents.Tickets.Domain.Policies.TicketLinkingPolicy do
  @moduledoc """
  Pure validation policy for ticket linking operations.

  Determines whether a ticket number is valid for linking to a session.
  Contains no I/O or database access.
  """

  @doc """
  Returns true if the given value is a valid ticket number (positive integer).
  """
  @spec valid_ticket_number?(term()) :: boolean()
  def valid_ticket_number?(number) when is_integer(number) and number > 0, do: true
  def valid_ticket_number?(_), do: false

  @doc """
  Returns true if linking should be attempted based on the ticket number.

  Returns true when the ticket number is present and valid.
  """
  @spec should_link?(term()) :: boolean()
  def should_link?(nil), do: false
  def should_link?(number), do: valid_ticket_number?(number)
end
