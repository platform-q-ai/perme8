defmodule Notifications.Test.Fixtures.AccountsFixtures do
  @moduledoc """
  Test helpers for creating user entities for notification tests.

  Creates user records directly via `Notifications.Repo` (same shared DB)
  to ensure visibility within the test sandbox connection.
  This avoids cross-repo sandbox visibility issues with `async: true`.
  """

  alias Notifications.Repo

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Creates a minimal user directly in the database via Notifications.Repo.

  Returns a map with `:id` and `:email` fields — enough for notification tests.
  Uses raw SQL insert to avoid depending on Identity schemas.
  """
  def user_fixture(attrs \\ %{}) do
    id = Map.get(attrs, :id, Ecto.UUID.generate())
    email = Map.get(attrs, :email, unique_user_email())
    now_utc = DateTime.utc_now() |> DateTime.truncate(:second)
    now_naive = DateTime.to_naive(now_utc)

    first_name = Map.get(attrs, :first_name, "Test")
    last_name = Map.get(attrs, :last_name, "User")

    Repo.query!(
      """
      INSERT INTO users (id, email, first_name, last_name, confirmed_at, date_created)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, email
      """,
      [Ecto.UUID.dump!(id), email, first_name, last_name, now_utc, now_naive]
    )

    %{id: id, email: email}
  end
end
