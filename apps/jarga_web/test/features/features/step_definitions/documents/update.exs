defmodule Documents.UpdateSteps do
  @moduledoc """
  Step definitions for document update operations.

  Covers:
  - Title updates
  - Visibility changes (public/private)
  - Pinning/unpinning documents
  - PubSub notifications for updates
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  alias Jarga.{Documents, Repo}
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  # ============================================================================
  # DOCUMENT TITLE UPDATE STEPS
  # ============================================================================

  step "I update the document title to {string}", %{args: [new_title]} = context do
    document = context[:document]
    user = context[:current_user]

    # Update via context
    result = Documents.update_document(user, document.id, %{title: new_title})

    case result do
      {:ok, updated_document} ->
        # Verify via LiveView (full-stack assertion)
        workspace = context[:workspace]
        conn = context[:conn]

        {:ok, _view, html} =
          live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{updated_document.slug}")

        assert html =~ new_title

        {:ok,
         context
         |> Map.put(:document, updated_document)
         |> Map.put(:last_result, result)
         |> Map.put(:last_html, html)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I attempt to update the document title to {string}", %{args: [new_title]} = context do
    document = context[:document]
    user = context[:current_user]

    result = Documents.update_document(user, document.id, %{title: new_title})
    {:ok, context |> Map.put(:last_result, result)}
  end

  # ============================================================================
  # DOCUMENT VISIBILITY STEPS
  # ============================================================================

  step "I make the document public", context do
    document = context[:document]
    user = context[:current_user]
    workspace = context[:workspace]

    # Subscribe to workspace PubSub to catch broadcasts
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    result = Documents.update_document(user, document.id, %{is_public: true})

    case result do
      {:ok, updated_document} ->
        {:ok,
         context
         |> Map.put(:document, updated_document)
         |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I make the document private", context do
    document = context[:document]
    user = context[:current_user]
    workspace = context[:workspace]

    # Subscribe to workspace PubSub to catch broadcasts
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    result = Documents.update_document(user, document.id, %{is_public: false})

    case result do
      {:ok, updated_document} ->
        {:ok,
         context
         |> Map.put(:document, updated_document)
         |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "the document should be public", context do
    document = Repo.get!(DocumentSchema, context[:document].id)
    assert document.is_public == true
    {:ok, context}
  end

  step "the document should be private", context do
    document = Repo.get!(DocumentSchema, context[:document].id)
    assert document.is_public == false
    {:ok, context}
  end

  step "a visibility changed notification should be broadcast", context do
    # Verify the PubSub broadcast was sent
    document = context[:document]

    assert_receive {:document_visibility_changed, document_id, is_public}, 1000
    assert document_id == document.id
    assert is_boolean(is_public)

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT PINNING STEPS
  # ============================================================================

  step "I pin the document", context do
    document = context[:document]
    user = context[:current_user]
    workspace = context[:workspace]

    # Subscribe to workspace PubSub to catch broadcasts
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    result = Documents.update_document(user, document.id, %{is_pinned: true})

    case result do
      {:ok, updated_document} ->
        {:ok,
         context
         |> Map.put(:document, updated_document)
         |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I attempt to pin the document", context do
    document = context[:document]
    user = context[:current_user]

    result = Documents.update_document(user, document.id, %{is_pinned: true})
    {:ok, context |> Map.put(:last_result, result)}
  end

  step "I unpin the document", context do
    document = context[:document]
    user = context[:current_user]

    result = Documents.update_document(user, document.id, %{is_pinned: false})

    case result do
      {:ok, updated_document} ->
        {:ok,
         context
         |> Map.put(:document, updated_document)
         |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "the document should be pinned", context do
    document = Repo.get!(DocumentSchema, context[:document].id)
    assert document.is_pinned == true
    {:ok, context}
  end

  step "the document should not be pinned", context do
    document = Repo.get!(DocumentSchema, context[:document].id)
    assert document.is_pinned == false
    {:ok, context}
  end

  step "a pin status changed notification should be broadcast", context do
    # Verify the PubSub broadcast was sent
    document = context[:document]

    assert_receive {:document_pinned_changed, document_id, is_pinned}, 1000
    assert document_id == document.id
    assert is_boolean(is_pinned)

    {:ok, context}
  end
end
