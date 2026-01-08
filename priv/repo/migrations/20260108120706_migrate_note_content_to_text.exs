defmodule Jarga.Repo.Migrations.MigrateNoteContentToText do
  use Ecto.Migration

  def up do
    # Add temporary column for the new text format
    alter table(:notes) do
      add(:note_content_text, :text)
    end

    # Migrate existing data: extract markdown from jsonb and store as plain text
    execute("""
    UPDATE notes
    SET note_content_text = 
      CASE 
        WHEN note_content IS NULL THEN NULL
        WHEN note_content->>'markdown' IS NOT NULL 
          THEN note_content->>'markdown'
        ELSE ''
      END
    """)

    # Drop old jsonb column
    alter table(:notes) do
      remove(:note_content)
    end

    # Rename new column to note_content
    rename(table(:notes), :note_content_text, to: :note_content)
  end

  def down do
    # Add temporary jsonb column
    alter table(:notes) do
      add(:note_content_jsonb, :jsonb)
    end

    # Migrate data back: wrap plain text in jsonb with markdown key
    execute("""
    UPDATE notes
    SET note_content_jsonb = 
      CASE 
        WHEN note_content IS NULL THEN NULL
        ELSE json_build_object('markdown', note_content)::jsonb
      END
    """)

    # Drop text column
    alter table(:notes) do
      remove(:note_content)
    end

    # Rename jsonb column back
    rename(table(:notes), :note_content_jsonb, to: :note_content)
  end
end
