defmodule Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository do
  @moduledoc """
  Infrastructure layer for UserToken data access.
  Provides database query execution functions for user tokens.

  Returns domain UserToken entities, not schemas.
  """

  @behaviour Jarga.Accounts.Application.Behaviours.UserTokenRepositoryBehaviour

  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Repo

  import Ecto.Query

  @doc """
  Gets a single token for a user by context.
  """
  def get_by_user_id_and_context(user_id, context, repo \\ Repo) do
    query = from(t in UserTokenSchema, where: t.user_id == ^user_id and t.context == ^context)

    repo.one(query)
    |> UserTokenSchema.to_entity()
  end

  @doc """
  Counts tokens for a user.
  """
  def count_by_user_id(user_id, repo \\ Repo) do
    query = from(t in UserTokenSchema, where: t.user_id == ^user_id)
    repo.aggregate(query, :count)
  end

  @doc """
  Executes a query and returns a single user token entity.

  Returns the token entity if found, nil otherwise.

  ## Examples

      iex> get_one(query)
      %UserToken{}

      iex> get_one(query)
      nil

  """
  @impl true
  def get_one(query, repo \\ Repo) do
    repo.one(query)
    |> UserTokenSchema.to_entity()
  end

  @doc """
  Gets all tokens for a user.

  Returns a list of token entities.

  ## Examples

      iex> all_by_user_id(user_id)
      [%UserToken{}, %UserToken{}]

      iex> all_by_user_id("non-existent")
      []

  """
  @impl true
  def all_by_user_id(user_id, repo \\ Repo) do
    repo.all_by(UserTokenSchema, user_id: user_id)
    |> Enum.map(&UserTokenSchema.to_entity/1)
  end

  @doc """
  Deletes a token.

  Accepts UserToken entity or UserTokenSchema.
  Returns the deleted token entity.

  ## Examples

      iex> delete!(token)
      %UserToken{}

  """
  @impl true
  def delete!(token, repo \\ Repo) do
    schema = UserTokenSchema.from_entity(token)
    deleted_schema = repo.delete!(schema)
    UserTokenSchema.to_entity(deleted_schema)
  end

  @doc """
  Deletes all tokens matching a query.

  Returns `{count, nil}` where count is the number of deleted tokens.

  ## Examples

      iex> delete_all(query)
      {2, nil}

  """
  @impl true
  def delete_all(query, repo \\ Repo) do
    repo.delete_all(query)
  end

  @doc """
  Inserts a new token.

  Accepts UserToken entity or UserTokenSchema.
  Returns the inserted token entity.

  Raises if insertion fails.

  ## Examples

      iex> insert!(token)
      %UserToken{}

  """
  @impl true
  def insert!(token, repo \\ Repo) do
    schema = UserTokenSchema.from_entity(token)

    # Support both module repos (Jarga.Repo) and map-based mock repos
    inserted_schema =
      if is_atom(repo) do
        repo.insert!(schema)
      else
        repo.insert!.(schema)
      end

    UserTokenSchema.to_entity(inserted_schema)
  end
end
