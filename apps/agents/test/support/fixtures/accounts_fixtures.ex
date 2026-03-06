defmodule Agents.Test.AccountsFixtures do
  @moduledoc """
  Test helpers for creating user records for Agents tests.

  Creates user records via raw SQL through `Identity.Repo` so they are visible
  to both the Identity facade (which queries through `Identity.Repo`) and
  Agents production code (which no longer has FK constraints to the users table,
  so `Agents.Repo` doesn't need to see the user row to insert agents).

  Follows the raw-SQL pattern from Notifications.Test.Fixtures.AccountsFixtures
  but uses `Identity.Repo` instead of `Agents.Repo` because the Identity facade
  is called at runtime.
  """

  use Boundary,
    top_level?: true,
    deps: [Identity.Repo],
    exports: []

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      first_name: "Test",
      last_name: "User"
    })
  end

  @doc """
  Creates a minimal confirmed user directly in the database via Identity.Repo.

  Returns a map with `:id`, `:email`, `:first_name`, and `:last_name` fields.
  Uses raw SQL insert to avoid depending on Identity schemas.
  """
  def user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)
    id = Map.get(attrs, :id, Ecto.UUID.generate())
    email = attrs.email
    first_name = attrs.first_name
    last_name = attrs.last_name
    now_utc = DateTime.utc_now() |> DateTime.truncate(:second)
    now_naive = DateTime.to_naive(now_utc)

    Identity.Repo.query!(
      """
      INSERT INTO users (id, email, first_name, last_name, confirmed_at, date_created, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      """,
      [Ecto.UUID.dump!(id), email, first_name, last_name, now_utc, now_naive, "active"]
    )

    %{id: id, email: email, first_name: first_name, last_name: last_name}
  end
end
