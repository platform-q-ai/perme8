defmodule Jarga.Pages.UseCases.UpdatePage do
  @moduledoc """
  Use case for updating a page.

  ## Business Rules

  - Actor must be a member of the workspace
  - Actor must have permission to edit the page (owner or admin, or page creator)
  - If updating is_pinned, actor must have pin permissions
  - Sends notifications when visibility, pin status, or title changes

  ## Responsibilities

  - Validate actor has workspace membership
  - Authorize update based on role and ownership
  - Update page attributes
  - Send appropriate notifications
  """

  @behaviour Jarga.Pages.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Pages.Page
  alias Jarga.Pages.Services.PubSubNotifier
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Executes the update page use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User updating the page
    - `:page_id` - ID of the page to update
    - `:attrs` - Page attributes to update

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service (default: PubSubNotifier)

  ## Returns

  - `{:ok, page}` - Page updated successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      page_id: page_id,
      attrs: attrs
    } = params

    notifier = Keyword.get(opts, :notifier, PubSubNotifier)

    with {:ok, page} <- get_page_with_workspace_member(actor, page_id),
         {:ok, member} <- Workspaces.get_member(actor, page.workspace_id),
         :ok <- authorize_page_update(member.role, page, actor.id, attrs) do
      update_page_and_notify(page, attrs, notifier)
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

  # Authorize page update based on role and ownership
  defp authorize_page_update(role, page, user_id, attrs) do
    owns_page = page.user_id == user_id

    # If updating is_pinned, check pin permissions
    if Map.has_key?(attrs, :is_pinned) do
      if PermissionsPolicy.can?(role, :pin_page,
           owns_resource: owns_page,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      # Otherwise check edit permissions
      if PermissionsPolicy.can?(role, :edit_page,
           owns_resource: owns_page,
           is_public: page.is_public
         ) do
        :ok
      else
        {:error, :forbidden}
      end
    end
  end

  # Update page and send notifications
  defp update_page_and_notify(page, attrs, notifier) do
    result =
      page
      |> Page.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_page} ->
        send_notifications(page, updated_page, attrs, notifier)
        {:ok, updated_page}

      error ->
        error
    end
  end

  # Send notifications for relevant changes
  defp send_notifications(old_page, updated_page, attrs, notifier) do
    if Map.has_key?(attrs, :is_public) and attrs.is_public != old_page.is_public do
      notifier.notify_page_visibility_changed(updated_page)
    end

    if Map.has_key?(attrs, :is_pinned) and attrs.is_pinned != old_page.is_pinned do
      notifier.notify_page_pinned_changed(updated_page)
    end

    if Map.has_key?(attrs, :title) and attrs.title != old_page.title do
      notifier.notify_page_title_changed(updated_page)
    end
  end
end
