defmodule Identity.AccountsFixtures do
  @moduledoc """
  Test fixtures for Identity accounts.

  This module provides test helpers for creating identity-related test data
  within the Identity app's test suite.
  """

  # Test fixture module - top-level boundary for test data creation
  # Needs access to Identity internals for fixture creation
  use Boundary,
    top_level?: true,
    deps: [Identity, Identity.Repo],
    exports: []

  import Ecto.Query

  alias Identity.Application.Services.PasswordService
  alias Identity.Domain.Entities.User
  alias Identity.Domain.Services.TokenBuilder
  alias Identity.Infrastructure.Schemas.{UserSchema, UserTokenSchema}

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      first_name: "Test",
      last_name: "User"
    })
  end

  @doc """
  Creates an unconfirmed user with the given attributes.
  """
  def unconfirmed_user_fixture(attrs \\ %{}) do
    user_attrs = valid_user_attributes(attrs)
    password = Map.get(user_attrs, :password, valid_user_password())

    # Register without password first
    {:ok, user} =
      user_attrs
      |> Map.delete(:password)
      |> Identity.register_user()

    # Then directly set hashed_password in database using PasswordService
    hashed_password = PasswordService.hash_password(password)

    # Update user directly in database (test helper)
    update_user_directly(user, hashed_password: hashed_password)
  end

  @doc """
  Creates a confirmed user with the given attributes.
  """
  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Identity.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Identity.login_user_by_magic_link(token)

    user
  end

  @doc """
  Extracts user token from a delivery function.
  """
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Overrides the authenticated_at timestamp for a token.
  Used for testing sudo mode and token expiration.
  """
  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Identity.Repo.update_all(
      from(t in UserTokenSchema,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  @doc """
  Generates a magic link token for a user.
  """
  def generate_user_magic_link_token(user) do
    {encoded_token, user_token_schema} = TokenBuilder.build_email_token(user, "login")
    Identity.Repo.insert!(user_token_schema)
    {encoded_token, user_token_schema.token}
  end

  @doc """
  Offsets a user token's timestamps by the given amount.
  """
  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Identity.Repo.update_all(
      from(ut in UserTokenSchema, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  @doc """
  Expires a user's login token for testing.
  """
  def expire_user_login_token(user_id) do
    Identity.Repo.update_all(
      from(t in UserTokenSchema,
        where: t.user_id == ^user_id and t.context == "login",
        update: [set: [inserted_at: fragment("inserted_at - INTERVAL '20 minutes'")]]
      ),
      []
    )
  end

  @doc """
  Sets a password for a user that doesn't have one.
  """
  def set_password(user) do
    hashed_password = PasswordService.hash_password(valid_user_password())
    update_user_directly(user, hashed_password: hashed_password)
  end

  # Private helper - updates user directly in database
  defp update_user_directly(%User{} = user, attrs) do
    updated_schema =
      user
      |> UserSchema.to_schema()
      |> Ecto.Changeset.change(attrs)
      |> Identity.Repo.update!()

    User.from_schema(updated_schema)
  end
end
