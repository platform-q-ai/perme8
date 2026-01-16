defmodule Jarga.Accounts.Domain.Policies.AuthenticationPolicy do
  @moduledoc """
  Pure business rules for user authentication.

  This module contains authentication-related business logic with zero
  infrastructure dependencies. All functions are pure and deterministic.

  ## Examples

      iex> user = %User{authenticated_at: DateTime.utc_now()}
      iex> AuthenticationPolicy.sudo_mode?(user)
      true

      iex> user = %User{authenticated_at: nil}
      iex> AuthenticationPolicy.sudo_mode?(user)
      false

  """

  alias Jarga.Accounts.Domain.Entities.User

  @default_sudo_mode_minutes -20

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than the specified time limit (default: 20 minutes ago).

  ## Parameters

    - user: The user struct (may be nil)
    - minutes: Time limit in minutes (default: -20, meaning 20 minutes ago)

  ## Returns

  Boolean indicating if the user is in sudo mode

  ## Examples

      iex> user = %User{authenticated_at: DateTime.utc_now()}
      iex> AuthenticationPolicy.sudo_mode?(user)
      true

      iex> old_auth = DateTime.utc_now() |> DateTime.add(-30, :minute)
      iex> user = %User{authenticated_at: old_auth}
      iex> AuthenticationPolicy.sudo_mode?(user)
      false

  """
  def sudo_mode?(user, minutes \\ @default_sudo_mode_minutes)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false
end
