defmodule Jarga.Documents.Services.NotificationService do
  @moduledoc """
  Behavior for document notification services.

  Defines the contract for sending notifications when documents are updated.
  This allows for dependency injection and easier testing with mock implementations.
  """

  alias Jarga.Documents.Document

  @doc """
  Notifies workspace members that a document's visibility has changed.
  """
  @callback notify_document_visibility_changed(document :: Document.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a document's pinned status has changed.
  """
  @callback notify_document_pinned_changed(document :: Document.t()) ::
              :ok | {:error, term()}

  @doc """
  Notifies workspace members that a document's title has changed.
  """
  @callback notify_document_title_changed(document :: Document.t()) ::
              :ok | {:error, term()}
end
