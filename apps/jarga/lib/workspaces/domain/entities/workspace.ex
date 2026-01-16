defmodule Jarga.Workspaces.Domain.Entities.Workspace do
  @moduledoc """
  Pure domain entity for workspaces.

  This is a value object representing a workspace in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          slug: String.t(),
          description: String.t() | nil,
          color: String.t() | nil,
          is_archived: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :slug,
    :description,
    :color,
    :inserted_at,
    :updated_at,
    is_archived: false
  ]

  @doc """
  Creates a new Workspace domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      slug: schema.slug,
      description: schema.description,
      color: schema.color,
      is_archived: schema.is_archived,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Validates workspace name (business rule).
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  def validate_name(_), do: {:error, :invalid_name}

  @doc """
  Checks if workspace is archived (business rule).
  """
  def archived?(%__MODULE__{is_archived: is_archived}), do: is_archived
end
