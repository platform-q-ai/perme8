defmodule Jarga.Accounts.Infrastructure.Repositories.UserRepository do
  @moduledoc """
  Repository for User data access operations.

  Provides a clean abstraction over database operations for User entities.
  Uses the Queries module for query building and accepts injectable repo
  for testability.

  ## Examples

      iex> UserRepository.get_by_id(user_id)
      %User{}
      
      iex> UserRepository.get_by_email("user@example.com")
      %User{}
      
      iex> UserRepository.exists?(user_id)
      true

  """

  @behaviour Jarga.Accounts.Application.Behaviours.UserRepositoryBehaviour

  import Ecto.Query, only: [from: 2]

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Accounts.Infrastructure.Queries.Queries

  # Users are now managed by Identity.Repo, not Jarga.Repo
  # This repository is deprecated and will be removed in Phase 6
  @default_repo Identity.Repo

  @doc """
  Gets a user by ID.

  Returns the user if found, nil otherwise.

  ## Parameters

    - id: The user ID to look up
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> UserRepository.get_by_id(user_id)
      %User{}
      
      iex> UserRepository.get_by_id("non-existent-id")
      nil

  """
  def get_by_id(id, repo \\ @default_repo) do
    case repo.get(UserSchema, id) do
      nil -> nil
      schema -> User.from_schema(schema)
    end
  end

  @doc """
  Gets a user by email address (case-insensitive).

  Returns the user if found, nil otherwise.

  ## Parameters

    - email: The email address to look up
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> UserRepository.get_by_email("user@example.com")
      %User{}
      
      iex> UserRepository.get_by_email("USER@EXAMPLE.COM")
      %User{}

  """
  def get_by_email(email, repo \\ @default_repo) when is_binary(email) do
    case Queries.by_email_case_insensitive(email) |> repo.one() do
      nil -> nil
      schema -> User.from_schema(schema)
    end
  end

  @doc """
  Checks if a user exists by ID.

  Returns true if the user exists, false otherwise.

  ## Parameters

    - id: The user ID to check
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> UserRepository.exists?(user_id)
      true
      
      iex> UserRepository.exists?("non-existent-id")
      false

  """
  def exists?(id, repo \\ @default_repo) do
    repo.exists?(from(u in UserSchema, where: u.id == ^id))
  end

  @doc """
  Creates and inserts a new user from attributes.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  ## Parameters

    - attrs: Map of user attributes
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> UserRepository.insert(%{email: "new@example.com", ...})
      {:ok, %User{}}
      
      iex> UserRepository.insert(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def insert(attrs, repo \\ @default_repo) when is_map(attrs) do
    case %UserSchema{}
         |> UserSchema.registration_changeset(attrs)
         |> repo.insert() do
      {:ok, schema} -> {:ok, User.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an existing user with new attributes.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  ## Parameters

    - user: The user struct to update
    - attrs: Map of attributes to update
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> UserRepository.update(user, %{first_name: "Updated"})
      {:ok, %User{}}
      
      iex> UserRepository.update(user, %{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update(user_or_schema, attrs, repo \\ @default_repo)

  def update(%User{} = user, attrs, repo) when is_map(attrs) do
    user
    |> UserSchema.to_schema()
    |> update(attrs, repo)
  end

  # Accept Identity.Domain.Entities.User and convert to Jarga user for processing
  def update(%Identity.Domain.Entities.User{} = identity_user, attrs, repo) when is_map(attrs) do
    # Convert Identity user to Jarga user, then delegate to the User clause
    jarga_user = %User{
      id: identity_user.id,
      first_name: identity_user.first_name,
      last_name: identity_user.last_name,
      email: identity_user.email,
      password: identity_user.password,
      hashed_password: identity_user.hashed_password,
      role: identity_user.role,
      status: identity_user.status,
      avatar_url: identity_user.avatar_url,
      confirmed_at: identity_user.confirmed_at,
      authenticated_at: identity_user.authenticated_at,
      last_login: identity_user.last_login,
      date_created: identity_user.date_created,
      preferences: identity_user.preferences || %{}
    }

    update(jarga_user, attrs, repo)
  end

  def update(%UserSchema{} = user_schema, attrs, repo) when is_map(attrs) do
    case user_schema
         |> Ecto.Changeset.cast(attrs, [
           :first_name,
           :last_name,
           :email,
           :hashed_password,
           :confirmed_at
         ])
         |> Ecto.Changeset.validate_required([:email])
         |> repo.update() do
      {:ok, schema} -> {:ok, User.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates a user using a changeset.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  This is a low-level function for use cases that need to use custom changesets.

  ## Parameters

    - changeset: The changeset to apply
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> changeset = User.email_changeset(user, %{email: "new@example.com"})
      iex> UserRepository.update_changeset(changeset)
      {:ok, %User{}}

  """
  @impl true
  def update_changeset(%Ecto.Changeset{} = changeset, repo \\ @default_repo) do
    case repo.update(changeset) do
      {:ok, schema} -> {:ok, User.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Inserts a new user using a changeset.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  This is a low-level function for use cases that need to use custom changesets.

  ## Parameters

    - changeset: The changeset to insert
    - repo: Optional repo for dependency injection (defaults to Identity.Repo)

  ## Examples

      iex> changeset = User.registration_changeset(%User{}, attrs)
      iex> UserRepository.insert_changeset(changeset)
      {:ok, %User{}}

  """
  @impl true
  def insert_changeset(%Ecto.Changeset{} = changeset, repo \\ @default_repo) do
    case repo.insert(changeset) do
      {:ok, schema} -> {:ok, User.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
