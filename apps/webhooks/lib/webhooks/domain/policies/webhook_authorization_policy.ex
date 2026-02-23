defmodule Webhooks.Domain.Policies.WebhookAuthorizationPolicy do
  @moduledoc """
  Pure authorization policy for webhook management.

  Determines which roles are allowed to manage webhook subscriptions
  and view webhook delivery logs.
  """

  @doc """
  Returns true if the given role is authorized to manage webhooks.

  Only `:owner` and `:admin` roles may create, update, delete, or
  view webhook subscriptions and their delivery logs.
  """
  @spec can_manage_webhooks?(atom()) :: boolean()
  def can_manage_webhooks?(:owner), do: true
  def can_manage_webhooks?(:admin), do: true
  def can_manage_webhooks?(_role), do: false
end
