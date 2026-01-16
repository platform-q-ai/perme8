defmodule Jarga.Accounts.Domain.Policies.TokenPolicy do
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
  Checks if a session token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> old = DateTime.utc_now() |> DateTime.add(-15, :day)
      iex> TokenPolicy.session_token_expired?(old)
      true

      iex> recent = DateTime.utc_now() |> DateTime.add(-5, :day)
      iex> TokenPolicy.session_token_expired?(recent)
      false

  """
  def session_token_expired?(timestamp) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@session_validity_in_days, :day)
    DateTime.compare(timestamp, cutoff) == :lt
  end

  @doc """
  Checks if a magic link token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> old = DateTime.utc_now() |> DateTime.add(-20, :minute)
      iex> TokenPolicy.magic_link_token_expired?(old)
      true

      iex> recent = DateTime.utc_now() |> DateTime.add(-10, :minute)
      iex> TokenPolicy.magic_link_token_expired?(recent)
      false

  """
  def magic_link_token_expired?(timestamp) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@magic_link_validity_in_minutes, :minute)
    DateTime.compare(timestamp, cutoff) == :lt
  end

  @doc """
  Checks if a change email token is expired based on its timestamp.

  ## Parameters

    - timestamp: DateTime when the token was created

  ## Returns

  Boolean indicating if the token is expired

  ## Examples

      iex> old = DateTime.utc_now() |> DateTime.add(-8, :day)
      iex> TokenPolicy.change_email_token_expired?(old)
      true

      iex> recent = DateTime.utc_now() |> DateTime.add(-3, :day)
      iex> TokenPolicy.change_email_token_expired?(recent)
      false

  """
  def change_email_token_expired?(timestamp) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@change_email_validity_in_days, :day)
    DateTime.compare(timestamp, cutoff) == :lt
  end
end
