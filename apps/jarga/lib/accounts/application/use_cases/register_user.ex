defmodule Jarga.Accounts.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for registering a new user.

  ## Business Rules

  - User must provide valid email, password, first name, and last name
  - Email must be unique (not already registered)
  - Password must meet format requirements (length, etc.)
  - Password is hashed using PasswordService before storage
  - User is created with status :active and date_created timestamp
  - User is not automatically confirmed (confirmed_at is nil)

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
  - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
  - `:password_service` - Password service module (default: PasswordService)

  ## Responsibilities

  - Validate registration attributes
  - Hash the password using PasswordService
  - Set default values (date_created, status)
  - Insert the new user into the database
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  import Ecto.Changeset, only: [get_change: 2, put_change: 3, delete_change: 2]

  alias Jarga.Accounts.Application.Services.PasswordService

  # Default implementations - can be overridden via opts for testing
  @default_repo Identity.Repo
  @default_user_schema Jarga.Accounts.Infrastructure.Schemas.UserSchema
  @default_user_repo Jarga.Accounts.Infrastructure.Repositories.UserRepository

  @doc """
  Executes the register user use case.

  ## Parameters

  - `params` - Map containing:
    - `:attrs` - User registration attributes (email, password, first_name, last_name)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
    - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
    - `:password_service` - Password service module (default: PasswordService)

  ## Returns

  - `{:ok, user}` - User registered successfully
  - `{:error, changeset}` - Validation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{attrs: attrs} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    user_schema = Keyword.get(opts, :user_schema, @default_user_schema)
    user_repo = Keyword.get(opts, :user_repo, @default_user_repo)
    password_service = Keyword.get(opts, :password_service, PasswordService)

    # Validate attributes
    changeset = user_schema.registration_changeset(struct(user_schema), attrs)

    # If changeset is valid and has a password, hash it
    changeset_with_hashed_password =
      if changeset.valid? && get_change(changeset, :password) do
        password = get_change(changeset, :password)
        hashed_password = password_service.hash_password(password)

        changeset
        |> put_change(:hashed_password, hashed_password)
        |> delete_change(:password)
      else
        changeset
      end

    # Insert user
    user_repo.insert_changeset(changeset_with_hashed_password, repo)
  end
end
