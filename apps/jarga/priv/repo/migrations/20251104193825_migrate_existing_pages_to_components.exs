defmodule Jarga.Repo.Migrations.MigrateExistingPagesToComponents do
  use Ecto.Migration

  import Ecto.Query

  def up do
    # Get all pages that have a note_id but no page_component entry
    pages_query = from p in "pages",
      where: not is_nil(p.note_id),
      select: %{id: p.id, note_id: p.note_id}

    pages = repo().all(pages_query)

    # Create page_component entries for each page
    Enum.each(pages, fn page ->
      # Check if page_component already exists
      existing_query = from pc in "page_components",
        where: pc.page_id == ^page.id and
               pc.component_type == "note" and
               pc.component_id == ^page.note_id

      unless repo().exists?(existing_query) do
        uuid_binary = Ecto.UUID.dump!(Ecto.UUID.generate())

        repo().insert_all("page_components", [
          %{
            id: uuid_binary,
            page_id: page.id,
            component_type: "note",
            component_id: page.note_id,
            position: 0,
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        ])
      end
    end)
  end

  def down do
    # Remove page_components that match the legacy note_id pattern
    # This allows rollback but keeps data intact
    :ok
  end
end
