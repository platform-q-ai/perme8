defmodule Jarga.Webhooks.Domain.Policies.WebhookPolicy do
  @moduledoc """
  Pure policy for webhook management authorization.

  Only admin and owner roles can manage webhook subscriptions.
  No I/O, no side effects.
  """

  @type role :: :guest | :member | :admin | :owner

  @doc """
  Checks if the given role can manage webhooks (create, update, delete, view).

  Returns `true` for `:admin` and `:owner` roles, `false` otherwise.
  """
  @spec can_manage_webhooks?(role()) :: boolean()
  def can_manage_webhooks?(role) when role in [:admin, :owner], do: true
  def can_manage_webhooks?(_role), do: false
end
