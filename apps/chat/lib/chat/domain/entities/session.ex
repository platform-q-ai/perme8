defmodule Chat.Domain.Entities.Session do
  @moduledoc """
  Pure domain entity for chat sessions.

  For database persistence, see Chat.Infrastructure.Schemas.SessionSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t() | nil,
          user_id: String.t(),
          workspace_id: String.t() | nil,
          project_id: String.t() | nil,
          messages: list(any()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :title,
    :user_id,
    :workspace_id,
    :project_id,
    :inserted_at,
    :updated_at,
    messages: []
  ]

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  def from_schema(%{__struct__: _} = schema) do
    alias Chat.Domain.Entities.Message

    messages =
      case schema.messages do
        nil -> []
        %Ecto.Association.NotLoaded{} -> []
        messages -> Enum.map(messages, &Message.from_schema/1)
      end

    %__MODULE__{
      id: schema.id,
      title: schema.title,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      project_id: schema.project_id,
      messages: messages,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
