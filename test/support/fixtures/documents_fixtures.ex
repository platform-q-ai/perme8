defmodule Jarga.DocumentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Documents` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Documents], exports: []

  alias Jarga.Documents

  def valid_document_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Test Document #{System.unique_integer([:positive])}",
      content: "Test document content"
    })
  end

  def document_fixture(user, workspace, project \\ nil, attrs \\ %{}) do
    attrs = valid_document_attributes(attrs)

    attrs =
      if project do
        Map.put(attrs, :project_id, project.id)
      else
        attrs
      end

    {:ok, document} = Documents.create_document(user, workspace.id, attrs)
    document
  end
end
