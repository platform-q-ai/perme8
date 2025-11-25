defmodule Jarga.Documents.Domain.Policies.DocumentAccessPolicy do
  @moduledoc """
  Pure domain logic for document access authorization.

  This policy encapsulates the business rules for determining whether
  a user can access (read) a document. It contains no infrastructure
  dependencies and operates purely on data structures.

  ## Access Rules

  A user can access a document if:
  - The user owns the document (created it), OR
  - The document is marked as public

  Private documents can only be accessed by their owner.
  """

  alias Jarga.Documents.Domain.Entities.Document

  @doc """
  Checks if a user can access a document.

  ## Parameters

  - `document` - The document to check access for
  - `user_id` - The ID of the user requesting access

  ## Returns

  Returns `true` if the user can access the document, `false` otherwise.

  ## Examples

      iex> document = %Document{user_id: "user-123", is_public: false}
      iex> DocumentAccessPolicy.can_access?(document, "user-123")
      true

      iex> document = %Document{user_id: "user-123", is_public: true}
      iex> DocumentAccessPolicy.can_access?(document, "user-456")
      true

      iex> document = %Document{user_id: "user-123", is_public: false}
      iex> DocumentAccessPolicy.can_access?(document, "user-456")
      false

  """
  @spec can_access?(Document.t(), binary()) :: boolean()
  def can_access?(%Document{} = document, user_id) do
    document.user_id == user_id || document.is_public
  end
end
