defmodule Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository do
  @moduledoc """
  Repository for note data access operations.

  Encapsulates all database operations for notes, following the Repository pattern.
  This keeps infrastructure concerns separated from application logic.
  """

  alias Identity.Repo, as: Repo
  alias Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema

  @doc """
  Gets a note by ID.

  Returns the note schema if found, nil otherwise.

  ## Examples

      iex> get_by_id(note_id)
      %NoteSchema{}

      iex> get_by_id("non-existent-id")
      nil
  """
  def get_by_id(note_id) do
    Repo.get(NoteSchema, note_id)
  end

  @doc """
  Creates a new note.

  ## Examples

      iex> create(%{id: uuid, user_id: user_id, workspace_id: workspace_id})
      {:ok, %NoteSchema{}}

      iex> create(%{})
      {:error, %Ecto.Changeset{}}
  """
  def create(attrs) do
    %NoteSchema{}
    |> NoteSchema.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing note.

  ## Examples

      iex> update(%NoteSchema{}, %{note_content: "updated content"})
      {:ok, %NoteSchema{}}

      iex> update(%NoteSchema{}, %{})
      {:ok, %NoteSchema{}}
  """
  def update(%NoteSchema{} = note, attrs) do
    note
    |> NoteSchema.changeset(attrs)
    |> Repo.update()
  end
end
