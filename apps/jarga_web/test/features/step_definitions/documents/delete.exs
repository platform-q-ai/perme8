defmodule Documents.DeleteSteps do
  @moduledoc """
  Step definitions for document deletion operations.

  Covers:
  - Deleting documents
  - Authorization checks
  - Cascade deletion verification  
  - PubSub notifications for deletion
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import ExUnit.Assertions

  alias Jarga.Documents
  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  alias Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository

  # ============================================================================
  # DOCUMENT DELETION STEPS
  # ============================================================================

  step "I delete the document", context do
    document = context[:document]
    user = context[:current_user]
    workspace = context[:workspace]

    # Subscribe to workspace PubSub to catch broadcasts
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    result = Documents.delete_document(user, document.id)

    case result do
      {:ok, _deleted_document} ->
        {:ok, context |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I attempt to delete the document", context do
    document = context[:document]
    user = context[:current_user]

    result = Documents.delete_document(user, document.id)
    {:ok, context |> Map.put(:last_result, result)}
  end

  step "the document should be deleted successfully", context do
    case context[:last_result] do
      {:ok, _} ->
        # Verify document no longer exists
        document_id = context[:document].id

        refute DocumentRepository.get_by_id(document_id)

        {:ok, context}

      _ ->
        flunk("Expected successful deletion, got: #{inspect(context[:last_result])}")
    end
  end

  step "the embedded note should also be deleted", context do
    # The note should be cascade deleted with the document
    # This is handled by database constraints (on_delete: :delete_all)
    document = context[:document]
    note = context[:note]
    note_id = note && note.id
    document_id = document && document.id

    # Verify note no longer exists (if we had one)
    note_deleted =
      case note_id &&
             NoteRepository.get_by_id(note_id) do
        nil -> true
        _ -> false
      end

    # Verify document no longer exists (if we had one)
    document_deleted =
      case document_id &&
             DocumentRepository.get_by_id(document_id) do
        nil -> true
        _ -> false
      end

    assert note_deleted || note_id == nil, "Expected embedded note to be deleted with document"
    assert document_deleted || document_id == nil, "Expected document to be deleted"

    {:ok, context}
  end

  step "a document deleted notification should be broadcast", context do
    # Verify the PubSub broadcast was sent
    document = context[:document]

    assert_receive {:document_deleted, document_id}, 1000
    assert document_id == document.id

    {:ok, context}
  end
end
