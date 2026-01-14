defmodule Documents.ComponentsSteps do
  @moduledoc """
  Step definitions for document components (embedded notes).

  Covers:
  - Note component assertions
  - Component loading
  - Component associations with projects
  - Component position and type
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import ExUnit.Assertions

  alias Jarga.Repo
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  # ============================================================================
  # DOCUMENT COMPONENTS STEPS
  # ============================================================================

  step "the document should have one note component", context do
    document = context[:document]
    # Fetch schema from DB to check components
    document_schema =
      DocumentSchema
      |> Repo.get!(document.id)
      |> Repo.preload(:document_components, force: true)

    assert length(document_schema.document_components) == 1
    {:ok, context}
  end

  step "the note component should be at position {int}", %{args: [position]} = context do
    document = context[:document]
    # Fetch schema from DB to check components
    document_schema =
      DocumentSchema
      |> Repo.get!(document.id)
      |> Repo.preload(:document_components, force: true)

    component = hd(document_schema.document_components)
    assert component.position == position
    {:ok, context}
  end

  step "the note component type should be {string}", %{args: [expected_type]} = context do
    document = context[:document]

    document_schema =
      DocumentSchema |> Repo.get!(document.id) |> Repo.preload(:document_components, force: true)

    component = hd(document_schema.document_components)
    assert component.component_type == expected_type
    {:ok, context}
  end

  step "I retrieve the document's note component", context do
    document = context[:document]

    document_schema =
      DocumentSchema |> Repo.get!(document.id) |> Repo.preload(:document_components)

    # Get the note component
    note_component = hd(document_schema.document_components)

    # Load the actual note using ComponentLoader
    alias Jarga.Documents.Application.Services.ComponentLoader
    note = ComponentLoader.load_component(note_component)

    {:ok, context |> Map.put(:note, note)}
  end

  step "I should receive the associated Note record", context do
    assert context[:note] != nil
    assert context[:note].id != nil
    {:ok, context}
  end

  step "the note should be editable", context do
    # Verify note exists and has expected structure
    note = context[:note]
    assert note.id != nil
    assert note.user_id != nil
    {:ok, context}
  end

  step "the embedded note should also be associated with project {string}",
       %{args: [_project_name]} = context do
    document = context[:document]

    document_schema =
      DocumentSchema |> Repo.get!(document.id) |> Repo.preload(:document_components)

    # Get the note component and load the actual note
    note_component = hd(document_schema.document_components)
    alias Jarga.Documents.Application.Services.ComponentLoader
    note = ComponentLoader.load_component(note_component)

    project = context[:project]

    assert note.project_id == project.id
    {:ok, context}
  end
end
