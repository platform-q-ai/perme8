defmodule Jarga.Accounts.Domain.Policies.ApiKeyPolicy do
  @moduledoc """
  Pure business rules for API key authorization.

  This module defines authorization rules for API key operations.
  All functions are deterministic with zero infrastructure dependencies.

  ## Authorization Rules

  - Users can only view their own API keys
  - Users can only manage (update, revoke) their own API keys
  - Ownership is determined by `user_id` match

  """

  @doc """
  Checks if a user owns an API key.

  A user owns an API key if the `user_id` matches the API key's `user_id`.

  ## Parameters

    - `api_key` - The ApiKey domain entity
    - `user_id` - The user ID to check

  ## Returns

  Boolean indicating if the user owns the API key

  ## Examples

      iex> api_key = ApiKey.new(%{user_id: "user_123", ...})
      iex> ApiKeyPolicy.can_own_api_key?(api_key, "user_123")
      true

      iex> ApiKeyPolicy.can_own_api_key?(api_key, "user_456")
      false

  """
  def can_own_api_key?(%{user_id: api_user_id}, user_id) do
    api_user_id == user_id
  end

  @doc """
  Checks if a user can manage an API key.

  A user can manage an API key if they own it.
  Management operations include: update, revoke.

  ## Parameters

    - `api_key` - The ApiKey domain entity
    - `user_id` - The user ID to check

  ## Returns

  Boolean indicating if the user can manage the API key

  ## Examples

      iex> api_key = ApiKey.new(%{user_id: "user_123", ...})
      iex> ApiKeyPolicy.can_manage_api_key?(api_key, "user_123")
      true

      iex> ApiKeyPolicy.can_manage_api_key?(api_key, "user_456")
      false

  """
  def can_manage_api_key?(%{user_id: api_user_id}, user_id) do
    api_user_id == user_id
  end
end
