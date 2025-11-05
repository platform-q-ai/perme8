defmodule Jarga.Pages.UseCases.DeletePage do
  @moduledoc """
  Use case for deleting a page.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to delete the page:
    - Own pages: Owner can delete if they have delete_page permission
    - Others' pages: Only admin/owner can delete public pages
  - Deletes the page (cascade will handle related records)

  ## Responsibilities

  - Validate actor has workspace membership
  - Authorize deletion based on role and ownership
  - Delete the page
  """

  @behaviour Jarga.Pages.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the delete page use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User deleting the page
    - `:page_id` - ID of the page to delete

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, page}` - Page deleted successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, _opts \\ []) do
    %{
      actor: actor,
      page_id: page_id
    } = params

    with {:ok, page} <- get_page_with_workspace_member(actor, page_id),
         {:ok, member} <- Workspaces.get_member(actor, page.workspace_id),
         :ok <- authorize_delete_page(member.role, page, actor.id) do
      Repo.delete(page)
    end
  end

  # Get page and verify workspace membership
  defp get_page_with_workspace_member(user, page_id) do
    alias Jarga.Pages.Infrastructure.PageRepository

    page = PageRepository.get_by_id(page_id)

    with {:page, %{} = page} <- {:page, page},
         {:ok, _workspace} <- Workspaces.verify_membership(user, page.workspace_id),
         :ok <- authorize_page_access(user, page) do
      {:ok, page}
    else
      {:page, nil} -> {:error, :page_not_found}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, _reason} -> {:error, :unauthorized}
    end
  end

  # Check if user can access this page
  defp authorize_page_access(user, page) do
    cond do
      page.user_id == user.id ->
        :ok

      page.is_public ->
        :ok

      true ->
        {:error, :forbidden}
    end
  end

  # Authorize page deletion based on role and ownership
  defp authorize_delete_page(role, page, user_id) do
    owns_page = page.user_id == user_id

    # For delete, we need to check if it's public when not the owner
    if owns_page do
      if PermissionsPolicy.can?(role, :delete_page, owns_resource: true) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      if PermissionsPolicy.can?(role, :delete_page,
           owns_resource: false,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    end
  end
end
