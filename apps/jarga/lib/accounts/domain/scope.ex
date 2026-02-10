defmodule Jarga.Accounts.Domain.Scope do
  @moduledoc """
  DEPRECATED: Use `Identity.Domain.Scope` instead.

  This module is maintained for backward compatibility during the migration
  to the Identity app. New code should use `Identity.Domain.Scope` directly.

  Defines the scope of the caller to be used throughout the app.

  The scope allows public interfaces to receive information about the caller,
  such as if the call is initiated from an end-user, and if so, which user.
  """

  alias Jarga.Accounts.Domain.Entities.User

  defstruct user: nil

  # Accept both Identity and Jarga user types since accounts module delegates to Identity
  @user_types [Identity.Domain.Entities.User, User]

  defguardp is_user(term)
            when is_struct(term) and :erlang.map_get(:__struct__, term) in @user_types

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(user) when is_user(user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
