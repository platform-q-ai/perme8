defmodule Identity.Domain.Policies.TokenPolicy do
  @moduledoc """
  Pure business rules for user token validation.

  This module defines validity periods for different token types and provides
  pure functions to check token expiration. All functions are deterministic
  with zero infrastructure dependencies.

  ## Token Types

  - **Session tokens**: Used for logged-in user sessions (14 days)
  - **Magic link tokens**: Used for passwordless login (15 minutes)
  - **Change email tokens**: Used for email change confirmation (7 days)

  ## Security Notes

  - Magic link tokens have a short expiry (15 minutes) for security
  - Session tokens are longer-lived but should still be periodically refreshed
  - Change email tokens expire after 7 days to prevent stale requests

  """

  @session_validity_in_days 14
  @magic_link_validity_in_minutes 15
  @change_email_validity_in_days 7
  @reset_password_validity_in_hours 1

  @doc """
  Returns the validity period for session tokens in days.
  """
  def session_validity_days, do: @session_validity_in_days

  @doc """
  Returns the validity period for magic link tokens in minutes.

  Note: This is intentionally short (15 minutes) for security reasons.
  """
  def magic_link_validity_minutes, do: @magic_link_validity_in_minutes

  @doc """
  Returns the validity period for change email tokens in days.
  """
  def change_email_validity_days, do: @change_email_validity_in_days

  @doc """
  Returns the validity period for password reset tokens in hours.

  Note: This is intentionally short (1 hour) for security reasons.
  """
  def reset_password_validity_hours, do: @reset_password_validity_in_hours

  @doc """
  Checks if a session token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created
    - current_time: Current DateTime for comparison (default: DateTime.utc_now())

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> old = ~U[2024-01-01 12:00:00Z]
      iex> TokenPolicy.session_token_expired?(old, now)
      true

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> recent = ~U[2024-01-10 12:00:00Z]
      iex> TokenPolicy.session_token_expired?(recent, now)
      false

  """
  def session_token_expired?(timestamp, current_time \\ DateTime.utc_now()) do
    cutoff = DateTime.add(current_time, -@session_validity_in_days, :day)
    DateTime.compare(timestamp, cutoff) == :lt
  end

  @doc """
  Checks if a magic link token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created
    - current_time: Current DateTime for comparison (default: DateTime.utc_now())

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> old = ~U[2024-01-15 11:30:00Z]
      iex> TokenPolicy.magic_link_token_expired?(old, now)
      true

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> recent = ~U[2024-01-15 11:50:00Z]
      iex> TokenPolicy.magic_link_token_expired?(recent, now)
      false

  """
  def magic_link_token_expired?(timestamp, current_time \\ DateTime.utc_now()) do
    cutoff = DateTime.add(current_time, -@magic_link_validity_in_minutes, :minute)
    DateTime.compare(timestamp, cutoff) == :lt
  end

  @doc """
  Checks if a change email token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created
    - current_time: Current DateTime for comparison (default: DateTime.utc_now())

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> old = ~U[2024-01-07 12:00:00Z]
      iex> TokenPolicy.change_email_token_expired?(old, now)
      true

      iex> now = ~U[2024-01-15 12:00:00Z]
      iex> recent = ~U[2024-01-12 12:00:00Z]
      iex> TokenPolicy.change_email_token_expired?(recent, now)
      false

  """
  def change_email_token_expired?(timestamp, current_time \\ DateTime.utc_now()) do
    cutoff = DateTime.add(current_time, -@change_email_validity_in_days, :day)
    DateTime.compare(timestamp, cutoff) == :lt
  end
end
