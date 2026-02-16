defmodule Agents.Test.AccountsFixtures do
  @moduledoc """
  Test helpers for creating user entities via the `Identity` context.

  This module replicates the user fixture logic from Jarga.AccountsFixtures
  using only the Identity public API, avoiding cross-app test support dependencies.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary,
    top_level?: true,
    deps: [Identity, Identity.Repo],
    exports: []

  alias Identity.Application.Services.PasswordService
  alias Identity.Domain.Entities.User
  alias Identity.Infrastructure.Schemas.UserSchema

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
      |> Identity.register_user()

    # Then directly set hashed_password in database using PasswordService
    hashed_password = PasswordService.hash_password(password)

    # Update user directly in database (test helper)
    update_user_directly(user, hashed_password: hashed_password)
  end

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

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
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
