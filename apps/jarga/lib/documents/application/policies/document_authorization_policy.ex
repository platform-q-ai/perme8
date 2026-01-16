defmodule Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy do
  @moduledoc """
  Application layer policies for document authorization.

  This module combines domain rules (from DocumentAccessPolicy) with
  workspace permission policies to determine what actions a user can
  perform on documents based on their role.

  This is an application-layer concern because it:
  - Coordinates between domain policies and workspace permissions
  - Orchestrates authorization decisions
  - Has knowledge of workspace roles and permissions
  """

  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy
  alias Jarga.Documents.Domain.Entities.Document

  @doc """
  Checks if a user can edit a document based on their role and ownership.

  ## Edit Rules

  - Users can edit their own documents
  - Members and admins can edit public documents
  - Admin cannot edit private documents they don't own
  - Guests cannot edit any documents

  ## Parameters

  - `document` - The document to check edit permission for
  - `role` - The user's role in the workspace (:owner, :admin, :member, :guest)
  - `user_id` - The ID of the user requesting edit access

  ## Returns

  Returns `true` if the user can edit the document, `false` otherwise.
  """
  @spec can_edit?(Document.t(), atom(), binary()) :: boolean()
  def can_edit?(%Document{} = document, role, user_id) do
    context = build_permission_context(document, user_id)
    PermissionsPolicy.can?(role, :edit_document, context)
  end

  @doc """
  Checks if a user can delete a document based on their role and ownership.

  ## Delete Rules

  - Users can delete their own documents
  - Admins can delete public documents
  - Admins cannot delete private documents they don't own
  - Members cannot delete documents they don't own
  - Guests cannot delete any documents

  ## Parameters

  - `document` - The document to check delete permission for
  - `role` - The user's role in the workspace (:owner, :admin, :member, :guest)
  - `user_id` - The ID of the user requesting delete access

  ## Returns

  Returns `true` if the user can delete the document, `false` otherwise.
  """
  @spec can_delete?(Document.t(), atom(), binary()) :: boolean()
  def can_delete?(%Document{} = document, role, user_id) do
    context = build_permission_context(document, user_id, include_public: :when_not_owner)
    PermissionsPolicy.can?(role, :delete_document, context)
  end

  @doc """
  Checks if a user can pin/unpin a document based on their role and ownership.

  ## Pin Rules

  - Users can pin their own documents
  - Members and admins can pin public documents
  - Members and admins cannot pin private documents they don't own
  - Guests cannot pin any documents

  ## Parameters

  - `document` - The document to check pin permission for
  - `role` - The user's role in the workspace (:owner, :admin, :member, :guest)
  - `user_id` - The ID of the user requesting pin access

  ## Returns

  Returns `true` if the user can pin the document, `false` otherwise.
  """
  @spec can_pin?(Document.t(), atom(), binary()) :: boolean()
  def can_pin?(%Document{} = document, role, user_id) do
    context = build_permission_context(document, user_id)
    PermissionsPolicy.can?(role, :pin_document, context)
  end

  # Private helper functions

  # Builds the context for PermissionsPolicy based on ownership and document visibility
  #
  # PermissionsPolicy has different pattern matches for owns_resource:
  # - When owns_resource: true, some actions need is_public, some don't
  # - When owns_resource: false, always needs is_public
  #
  # The include_public option controls when to include is_public in the context:
  # - :always - Include is_public in both owner and non-owner cases
  # - :when_not_owner - Only include is_public when user doesn't own the resource
  defp build_permission_context(document, user_id, opts \\ []) do
    owns_document = document.user_id == user_id
    include_public = Keyword.get(opts, :include_public, :always)

    case {owns_document, include_public} do
      {true, :when_not_owner} ->
        [owns_resource: true]

      {true, :always} ->
        [owns_resource: true, is_public: document.is_public]

      {false, _} ->
        [owns_resource: false, is_public: document.is_public]
    end
  end
end
