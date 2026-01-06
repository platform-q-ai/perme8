defmodule Jarga.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Accounts` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Accounts, Jarga.Repo], exports: []

  import Ecto.Query

  alias Jarga.Accounts
  alias Jarga.Accounts.Application.Services.{ApiKeyTokenService, PasswordService}
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Domain.Scope
  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Schemas.{ApiKeySchema, UserSchema, UserTokenSchema}

  # Private test helper - updates user directly in database
  defp update_user_directly(user, attrs) do
    updated_schema =
      user
      |> UserSchema.to_schema()
      |> Ecto.Changeset.change(attrs)
      |> Jarga.Repo.update!()

    User.from_schema(updated_schema)
  end

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

  def unconfirmed_user_fixture(attrs \\ %{}) do
    user_attrs = valid_user_attributes(attrs)
    password = Map.get(user_attrs, :password, valid_user_password())

    # Register without password first
    {:ok, user} =
      user_attrs
      |> Map.delete(:password)
      |> Accounts.register_user()

    # Then directly set hashed_password in database using PasswordService
    hashed_password = PasswordService.hash_password(password)

    # Update user directly in database (test helper)
    update_user_directly(user, hashed_password: hashed_password)
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Accounts.login_user_by_magic_link(token)

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    hashed_password = PasswordService.hash_password(valid_user_password())

    # Update user directly in database (test helper)
    update_user_directly(user, hashed_password: hashed_password)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Jarga.Repo.update_all(
      from(t in UserTokenSchema,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token_schema} = TokenBuilder.build_email_token(user, "login")
    Jarga.Repo.insert!(user_token_schema)
    {encoded_token, user_token_schema.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Jarga.Repo.update_all(
      from(ut in UserTokenSchema, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  def expire_user_login_token(user_id) do
    Jarga.Repo.update_all(
      from(t in UserTokenSchema,
        where: t.user_id == ^user_id and t.context == "login",
        update: [set: [inserted_at: fragment("inserted_at - INTERVAL '20 minutes'")]]
      ),
      []
    )
  end

  @doc """
  Creates an API key directly in the database without workspace validation.

  This is useful for testing edge cases where an API key has access to a
  workspace that doesn't exist (e.g., workspace was deleted after API key
  was created).

  Returns `{api_key_entity, plain_token}`.
  """
  def api_key_fixture_without_validation(user_id, attrs \\ %{}) do
    plain_token = ApiKeyTokenService.generate_token()
    hashed_token = ApiKeyTokenService.hash_token(plain_token)

    api_key_attrs = %{
      name: Map.get(attrs, :name, "Test API Key"),
      description: Map.get(attrs, :description),
      hashed_token: hashed_token,
      user_id: user_id,
      workspace_access: Map.get(attrs, :workspace_access, []),
      is_active: Map.get(attrs, :is_active, true)
    }

    {:ok, schema} =
      %ApiKeySchema{}
      |> ApiKeySchema.changeset(api_key_attrs)
      |> Jarga.Repo.insert()

    api_key = ApiKeySchema.to_entity(schema)
    {api_key, plain_token}
  end
end
