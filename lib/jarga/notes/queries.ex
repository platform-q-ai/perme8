defmodule Jarga.Notes.Queries do
  @moduledoc """
  Query objects for the Notes context.
  Provides composable query functions for building database queries.
  """

  import Ecto.Query
  alias Jarga.Notes.Note
  alias Jarga.Accounts.User

  @doc """
  Base query for notes.
  """
  def base do
    from(n in Note, as: :note)
  end

  @doc """
  Filter notes by user.
  """
  def for_user(query, %User{id: user_id}) do
    from([note: n] in query,
      where: n.user_id == ^user_id
    )
  end

  @doc """
  Filter notes by workspace.
  """
  def for_workspace(query, workspace_id) do
    from([note: n] in query,
      where: n.workspace_id == ^workspace_id
    )
  end

  @doc """
  Filter notes by project.
  """
  def for_project(query, project_id) do
    from([note: n] in query,
      where: n.project_id == ^project_id
    )
  end

  @doc """
  Filter notes by ID.
  """
  def by_id(query, note_id) do
    from([note: n] in query,
      where: n.id == ^note_id
    )
  end

  @doc """
  Order notes by creation date (newest first).
  """
  def ordered(query) do
    from([note: n] in query,
      order_by: [desc: n.inserted_at]
    )
  end
end
