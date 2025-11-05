defmodule Jarga.Pages.PageComponentTest do
  use Jarga.DataCase, async: true

  alias Jarga.Pages.PageComponent
  alias Jarga.Pages.Services.ComponentLoader
  alias Jarga.{Pages, Notes}

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Test"})
      note_id = Ecto.UUID.generate()
      {:ok, note} = Notes.create_note(user, workspace.id, %{id: note_id})

      attrs = %{
        page_id: page.id,
        component_type: "note",
        component_id: note.id,
        position: 1
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :page_id) == page.id
      assert get_change(changeset, :component_type) == "note"
      assert get_change(changeset, :component_id) == note.id
      assert get_change(changeset, :position) == 1
    end

    test "invalid changeset when page_id is missing" do
      attrs = %{
        component_type: "note",
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).page_id
    end

    test "invalid changeset when component_type is missing" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).component_type
    end

    test "invalid changeset when component_id is missing" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "note",
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).component_id
    end

    test "position defaults to 0 when not provided" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "note",
        component_id: Ecto.UUID.generate()
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      assert changeset.valid?
      # Position field defaults to 0 as defined in the schema
    end

    test "invalid changeset with invalid component_type" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "invalid_type",
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).component_type
    end

    test "valid changeset with component_type 'note'" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "note",
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with component_type 'task_list'" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "task_list",
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with component_type 'sheet'" do
      attrs = %{
        page_id: Ecto.UUID.generate(),
        component_type: "sheet",
        component_id: Ecto.UUID.generate(),
        position: 0
      }

      changeset = PageComponent.changeset(%PageComponent{}, attrs)

      assert changeset.valid?
    end
  end

  describe "get_component/1" do
    test "returns note when component_type is 'note'" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()
      {:ok, note} = Notes.create_note(user, workspace.id, %{id: note_id})

      page_component = %PageComponent{
        component_type: "note",
        component_id: note.id
      }

      fetched_note = ComponentLoader.load_component(page_component)

      assert fetched_note.id == note.id
    end

    test "returns nil when note doesn't exist" do
      page_component = %PageComponent{
        component_type: "note",
        component_id: Ecto.UUID.generate()
      }

      assert ComponentLoader.load_component(page_component) == nil
    end

    test "returns nil for task_list component (not yet implemented)" do
      page_component = %PageComponent{
        component_type: "task_list",
        component_id: Ecto.UUID.generate()
      }

      assert ComponentLoader.load_component(page_component) == nil
    end

    test "returns nil for sheet component (not yet implemented)" do
      page_component = %PageComponent{
        component_type: "sheet",
        component_id: Ecto.UUID.generate()
      }

      assert ComponentLoader.load_component(page_component) == nil
    end
  end
end
