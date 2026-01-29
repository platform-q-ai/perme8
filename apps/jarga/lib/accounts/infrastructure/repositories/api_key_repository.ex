defmodule Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository do
  @moduledoc """
  Repository for API key data access.

  This is a thin wrapper around Ecto.Repo for API key operations.
  Uses ApiKeyQueries for query construction and returns domain entities.

  ## Usage

      # Insert API key
      ApiKeyRepository.insert(repo, %{name: "Test", hashed_token: "...", user_id: user_id})

      # Get by ID
      {:ok, api_key} = ApiKeyRepository.get_by_id(repo, id)

      # List by user
      {:ok, keys} = ApiKeyRepository.list_by_user_id(repo, user_id)

  """

  alias Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema
  alias Jarga.Accounts.Infrastructure.Queries.ApiKeyQueries

  @doc """
  Inserts a new API key.

  ## Parameters

    - `repo` - Ecto.Repo
    - `attrs` - Map with API key attributes

  ## Returns

    `{:ok, schema}` on success
    `{:error, changeset}` on validation error

  """
  def insert(repo, attrs) do
    %ApiKeySchema{}
    |> ApiKeySchema.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing API key.

  Can be called with either an API key ID (string) or an ApiKeySchema struct.

  ## Parameters

    - `repo` - Ecto.Repo
    - `api_key_id` or `schema` - API key ID (string) or ApiKeySchema struct
    - `attrs` - Map with fields to update

  ## Returns

    When called with ID:
    - `{:ok, ApiKey.t()}` on success (returns domain entity)
    - `{:error, :not_found}` if not found
    - `{:error, changeset}` on validation error

    When called with schema:
    - `{:ok, updated_schema}` on success (returns Ecto schema)
    - `{:error, changeset}` on validation error

  """
  def update(repo, api_key_id, attrs) when is_binary(api_key_id) do
    case repo.get(ApiKeySchema, api_key_id) do
      nil ->
        {:error, :not_found}

      schema ->
        case update(repo, schema, attrs) do
          {:ok, updated_schema} -> {:ok, ApiKeySchema.to_entity(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def update(repo, %ApiKeySchema{} = api_key, attrs) do
    api_key
    |> ApiKeySchema.changeset(attrs)
    |> repo.update()
  end

  @doc """
  Gets an API key by ID.

  ## Parameters

    - `repo` - Ecto.Repo
    - `id` - API key ID

  ## Returns

    `{:ok, ApiKey.t()}` on success
    `{:error, :not_found}` if not found
  """
  def get_by_id(repo, id) do
    query = ApiKeyQueries.base() |> ApiKeyQueries.by_id(id)

    case repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, ApiKeySchema.to_entity(schema)}
    end
  end

  @doc """
  Gets an API key by hashed token.

  ## Parameters

    - `repo` - Ecto.Repo
    - `hashed_token` - Hashed token to search for

  ## Returns

    `{:ok, ApiKey.t()}` on success
    `{:error, :not_found}` if not found
  """
  def get_by_hashed_token(repo, hashed_token) do
    query = ApiKeyQueries.base() |> ApiKeyQueries.by_hashed_token(hashed_token)

    case repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, ApiKeySchema.to_entity(schema)}
    end
  end

  @doc """
  Lists all API keys for a user.

  ## Parameters

    - `repo` - Ecto.Repo
    - `user_id` - User ID to filter by

  ## Returns

    `{:ok, [ApiKey.t()]}` - List of API keys
  """
  def list_by_user_id(repo, user_id) do
    query =
      ApiKeyQueries.base()
      |> ApiKeyQueries.by_user_id(user_id)

    {:ok, repo.all(query) |> Enum.map(&ApiKeySchema.to_entity/1)}
  end

  @doc """
  Checks if an API key exists by ID and hashed token.

  ## Parameters

    - `repo` - Ecto.Repo
    - `id` - API key ID
    - `hashed_token` - Hashed token to check

  ## Returns

    `true` if exists, `false` otherwise
  """
  def exists_by_id_and_hashed_token?(repo, id, hashed_token) do
    query =
      ApiKeyQueries.base()
      |> ApiKeyQueries.by_id(id)
      |> ApiKeyQueries.by_hashed_token(hashed_token)

    repo.exists?(query)
  end

  @doc """
  Deletes all API keys for a user.

  ## Parameters

    - `repo` - Ecto.Repo
    - `user_id` - User ID whose API keys should be deleted

  ## Returns

    `{count, nil}` where count is the number of deleted records
  """
  def delete_by_user_id(repo, user_id) do
    query =
      ApiKeyQueries.base()
      |> ApiKeyQueries.by_user_id(user_id)

    repo.delete_all(query)
  end
end
