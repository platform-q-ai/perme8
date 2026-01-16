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

  ## Responsibilities

  - Validate registration attributes
  - Hash the password using PasswordService
  - Set default values (date_created, status)
  - Insert the new user into the database
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  import Ecto.Changeset, only: [get_change: 2, put_change: 3, delete_change: 2]

  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Accounts.Application.Services.PasswordService
  alias Jarga.Accounts.Infrastructure.Repositories.UserRepository

  @doc """
  Executes the register user use case.

  ## Parameters

  - `params` - Map containing:
    - `:attrs` - User registration attributes (email, password, first_name, last_name)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:password_service` - Password service module (default: PasswordService)

  ## Returns

  - `{:ok, user}` - User registered successfully
  - `{:error, changeset}` - Validation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{attrs: attrs} = params

    repo = Keyword.get(opts, :repo, Jarga.Repo)
    password_service = Keyword.get(opts, :password_service, PasswordService)

    # Validate attributes
    changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)

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
    UserRepository.insert_changeset(changeset_with_hashed_password, repo)
  end
end
