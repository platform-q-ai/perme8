defmodule Notifications.Domain.Entities.Notification do
  @moduledoc """
  Domain entity representing a notification.

  This is a pure data structure with no database dependencies.
  It represents a notification in the business domain.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          user_id: String.t() | nil,
          type: String.t() | nil,
          title: String.t() | nil,
          body: String.t() | nil,
          data: map(),
          read: boolean(),
          read_at: DateTime.t() | nil,
          action_taken_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :type,
    :title,
    :body,
    data: %{},
    read: false,
    read_at: nil,
    action_taken_at: nil,
    inserted_at: nil,
    updated_at: nil
  ]

  @doc """
  Creates a new Notification entity from an attrs map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts a schema-like map or struct to a Notification entity.
  """
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    attrs =
      Map.take(schema, [
        :id,
        :user_id,
        :type,
        :title,
        :body,
        :data,
        :read,
        :read_at,
        :action_taken_at,
        :inserted_at,
        :updated_at
      ])

    struct(__MODULE__, attrs)
  end
end
