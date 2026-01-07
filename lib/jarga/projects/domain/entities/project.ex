defmodule Jarga.Projects.Domain.Entities.Project do
  @moduledoc """
  Pure domain entity for projects.

  This is a pure Elixir struct with no infrastructure dependencies.
  It represents the core business concept of a project.

  Following Domain Layer principles:
  - No Ecto dependencies
  - Pure data structure
  - Can contain domain validation logic (business rules)
  - No database or persistence concerns
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          slug: String.t(),
          description: String.t() | nil,
          color: String.t() | nil,
          is_default: boolean(),
          is_archived: boolean(),
          user_id: String.t(),
          workspace_id: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :slug,
    :description,
    :color,
    :user_id,
    :workspace_id,
    :inserted_at,
    :updated_at,
    is_default: false,
    is_archived: false
  ]

  @doc """
  Creates a new project entity.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Validates project name (business rule).
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  def validate_name(_), do: {:error, :invalid_name}

  @doc """
  Checks if project is archived (business rule).
  """
  def archived?(%__MODULE__{is_archived: is_archived}), do: is_archived

  @doc """
  Checks if project is default (business rule).
  """
  def default?(%__MODULE__{is_default: is_default}), do: is_default

  @doc """
  Converts a schema struct to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      slug: schema.slug,
      description: schema.description,
      color: schema.color,
      is_default: schema.is_default,
      is_archived: schema.is_archived,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
