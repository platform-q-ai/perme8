defmodule Jarga.Pages.Services.NotificationService do
  @moduledoc """
  Behavior for page notification services.

  Defines the contract for sending notifications when pages are updated.
  This allows for dependency injection and easier testing with mock implementations.
  """

  alias Jarga.Pages.Page

  @doc """
  Notifies workspace members that a page's visibility has changed.
  """
  @callback notify_page_visibility_changed(page :: Page.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a page's pinned status has changed.
  """
  @callback notify_page_pinned_changed(page :: Page.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a page's title has changed.
  """
  @callback notify_page_title_changed(page :: Page.t()) ::
              :ok | {:error, term()}
end
