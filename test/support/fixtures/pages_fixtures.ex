defmodule Jarga.PagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Pages` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Pages], exports: []

  alias Jarga.Pages

  def valid_page_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Test Page #{System.unique_integer([:positive])}",
      content: "Test page content"
    })
  end

  def page_fixture(user, workspace, project \\ nil, attrs \\ %{}) do
    attrs = valid_page_attributes(attrs)

    attrs =
      if project do
        Map.put(attrs, :project_id, project.id)
      else
        attrs
      end

    {:ok, page} = Pages.create_page(user, workspace.id, attrs)
    page
  end
end
