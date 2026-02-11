defmodule Identity.Infrastructure.Queries.ApiKeyQueries do
  @moduledoc """
  Composable Ecto queries for API keys.

  This module provides query builders for common API key queries.
  All functions return Ecto.Query structs, not results.

  ## Usage

      ApiKeyQueries.base()
      |> ApiKeyQueries.by_user_id(user_id)
      |> ApiKeyQueries.active()
      |> Repo.all()

  """

  import Ecto.Query

  alias Identity.Infrastructure.Schemas.ApiKeySchema

  @doc """
  Returns the base query for API keys.

  ## Examples

      iex> query = ApiKeyQueries.base()
      iex> query.from
      {ApiKeySchema, nil}

  """
  def base do
    from(a in ApiKeySchema, as: :api_key)
  end

  @doc """
  Filters query by user_id.

  ## Parameters

    - `query` - Ecto.Query
    - `user_id` - User ID to filter by

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.by_user_id(user_id)

  """
  def by_user_id(query, user_id) do
    where(query, [api_key], api_key.user_id == ^user_id)
  end

  @doc """
  Filters query by API key id.

  ## Parameters

    - `query` - Ecto.Query
    - `id` - API key ID to filter by

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.by_id(api_key_id)

  """
  def by_id(query, id) do
    where(query, [api_key], api_key.id == ^id)
  end

  @doc """
  Filters query by hashed_token.

  ## Parameters

    - `query` - Ecto.Query
    - `hashed_token` - Hashed token to filter by

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.by_hashed_token(hashed_token)

  """
  def by_hashed_token(query, hashed_token) do
    where(query, [api_key], api_key.hashed_token == ^hashed_token)
  end

  @doc """
  Filters query for active API keys (is_active = true).

  ## Parameters

    - `query` - Ecto.Query

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.active()

  """
  def active(query) do
    where(query, [api_key], api_key.is_active == true)
  end

  @doc """
  Filters query for inactive API keys (is_active = false).

  ## Parameters

    - `query` - Ecto.Query

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.inactive()

  """
  def inactive(query) do
    where(query, [api_key], api_key.is_active == false)
  end

  @doc """
  Preloads user association for the query.

  ## Parameters

    - `query` - Ecto.Query

  ## Examples

      iex> query = ApiKeyQueries.base() |> ApiKeyQueries.preload_user()

  """
  def preload_user(query) do
    preload(query, [:user])
  end
end
