defmodule Agents.Test.WorkspacesFixtures do
  @moduledoc """
  Test helpers for creating workspace records for Agents tests.

  Creates workspace and workspace_member records via raw SQL through
  `Identity.Repo` so they are visible to the Identity facade at runtime.
  Since cross-app FK constraints have been dropped, `Agents.Repo` can reference
  these rows without needing direct visibility.
  """

  use Boundary,
    top_level?: true,
    deps: [Identity.Repo],
    exports: []

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Workspace #{System.unique_integer([:positive])}",
      description: "A test workspace",
      color: "#4A90E2"
    })
  end

  @doc """
  Creates a workspace directly in the database via Identity.Repo.

  Also creates an owner workspace_members entry for the given user.
  Returns a map with `:id`, `:name`, and `:slug` fields.
  """
  def workspace_fixture(user, attrs \\ %{}) do
    attrs = valid_workspace_attributes(attrs)
    id = Ecto.UUID.generate()
    name = Map.get(attrs, :name)
    description = Map.get(attrs, :description)
    color = Map.get(attrs, :color)
    slug = generate_slug(name, id)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Identity.Repo.query!(
      """
      INSERT INTO workspaces (id, name, description, color, slug, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      """,
      [Ecto.UUID.dump!(id), name, description, color, slug, now, now]
    )

    # Add the creating user as workspace owner
    insert_workspace_member(id, user, "owner", now)

    %{id: id, name: name, slug: slug}
  end

  @doc """
  Adds a workspace member directly (bypassing invitation flow).

  This is for testing purposes only. Returns a map with the member details.
  """
  def add_workspace_member_fixture(workspace_id, user, role) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    %{id: id} = insert_workspace_member(workspace_id, user, to_string(role), now)
    %{id: id, workspace_id: workspace_id, user_id: user.id, role: role}
  end

  # -- Private helpers --

  defp generate_slug(name, id) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> Kernel.<>("-" <> String.slice(id, 0..7))
  end

  defp insert_workspace_member(workspace_id, user, role, now) do
    id = Ecto.UUID.generate()

    Identity.Repo.query!(
      """
      INSERT INTO workspace_members (id, workspace_id, user_id, email, role, invited_at, joined_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      """,
      [
        Ecto.UUID.dump!(id),
        Ecto.UUID.dump!(workspace_id),
        Ecto.UUID.dump!(user.id),
        user.email,
        role,
        now,
        now,
        now,
        now
      ]
    )

    %{id: id}
  end
end
