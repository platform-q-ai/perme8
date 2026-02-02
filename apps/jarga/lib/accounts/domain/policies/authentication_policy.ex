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
    - opts: Keyword list of options
      - `:minutes` - Time limit in minutes (default: -20, meaning 20 minutes ago)
      - `:current_time` - Current DateTime for comparison (default: DateTime.utc_now())

  ## Returns

  Boolean indicating if the user is in sudo mode

  ## Examples

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> user = %User{authenticated_at: ~U[2024-01-15 11:50:00Z]}
      iex> AuthenticationPolicy.sudo_mode?(user, current_time: now)
      true

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> user = %User{authenticated_at: ~U[2024-01-15 11:30:00Z]}
      iex> AuthenticationPolicy.sudo_mode?(user, current_time: now)
      false

  """
  def sudo_mode?(user, opts \\ [])

  def sudo_mode?(%User{authenticated_at: ts}, opts) when is_struct(ts, DateTime) do
    minutes = Keyword.get(opts, :minutes, @default_sudo_mode_minutes)
    current_time = Keyword.get(opts, :current_time, DateTime.utc_now())
    cutoff = DateTime.add(current_time, minutes, :minute)
    DateTime.after?(ts, cutoff)
  end

  def sudo_mode?(_user, _opts), do: false
end
