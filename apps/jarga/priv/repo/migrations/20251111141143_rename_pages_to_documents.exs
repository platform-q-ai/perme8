defmodule Jarga.Repo.Migrations.RenamePagesToDocuments do
  use Ecto.Migration

  def up do
    # Step 1: Rename pages table to documents
    rename table(:pages), to: table(:documents)

    # Step 2: Rename page_components table to document_components
    rename table(:page_components), to: table(:document_components)

    # Step 3: Rename foreign key columns
    # In document_components, rename page_id to document_id
    rename table(:document_components), :page_id, to: :document_id

    # In sheet_rows, rename page_id to document_id (if it exists)
    # This column is nullable, so it's safe to rename
    rename table(:sheet_rows), :page_id, to: :document_id

    # Step 4: Rename primary key constraints
    execute "ALTER INDEX pages_pkey RENAME TO documents_pkey"
    execute "ALTER INDEX page_components_pkey RENAME TO document_components_pkey"

    # Step 5: Rename other indexes on documents table
    execute "ALTER INDEX pages_user_id_index RENAME TO documents_user_id_index"
    execute "ALTER INDEX pages_workspace_id_index RENAME TO documents_workspace_id_index"
    execute "ALTER INDEX pages_project_id_index RENAME TO documents_project_id_index"
    execute "ALTER INDEX pages_workspace_id_slug_index RENAME TO documents_workspace_id_slug_index"

    # Step 6: Rename indexes on document_components table
    execute "ALTER INDEX page_components_page_id_index RENAME TO document_components_document_id_index"
    execute "ALTER INDEX page_components_component_type_component_id_index RENAME TO document_components_component_type_component_id_index"
    execute "ALTER INDEX page_components_page_id_component_type_component_id_index RENAME TO document_components_document_id_component_type_component_id_index"

    # Step 7: Rename foreign key constraints
    # Note: Constraint names may vary depending on how they were created
    # We'll attempt to rename them, but they might not exist with these exact names
    execute """
    DO $$
    BEGIN
      -- Rename foreign key constraint on document_components
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'page_components_page_id_fkey'
        AND table_name = 'document_components'
      ) THEN
        ALTER TABLE document_components
        RENAME CONSTRAINT page_components_page_id_fkey TO document_components_document_id_fkey;
      END IF;

      -- Rename foreign key constraint on sheet_rows
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'sheet_rows_page_id_fkey'
        AND table_name = 'sheet_rows'
      ) THEN
        ALTER TABLE sheet_rows
        RENAME CONSTRAINT sheet_rows_page_id_fkey TO sheet_rows_document_id_fkey;
      END IF;
    END $$;
    """

    # Step 8: Rename unique constraint on documents
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'pages_workspace_id_slug_index'
        AND table_name = 'documents'
        AND constraint_type = 'UNIQUE'
      ) THEN
        ALTER TABLE documents
        RENAME CONSTRAINT pages_workspace_id_slug_index TO documents_workspace_id_slug_index;
      END IF;
    END $$;
    """
  end

  def down do
    # Reverse all changes in opposite order

    # Rename unique constraint back
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'documents_workspace_id_slug_index'
        AND table_name = 'documents'
        AND constraint_type = 'UNIQUE'
      ) THEN
        ALTER TABLE documents
        RENAME CONSTRAINT documents_workspace_id_slug_index TO pages_workspace_id_slug_index;
      END IF;
    END $$;
    """

    # Rename foreign key constraints back
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'document_components_document_id_fkey'
        AND table_name = 'document_components'
      ) THEN
        ALTER TABLE document_components
        RENAME CONSTRAINT document_components_document_id_fkey TO page_components_page_id_fkey;
      END IF;

      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'sheet_rows_document_id_fkey'
        AND table_name = 'sheet_rows'
      ) THEN
        ALTER TABLE sheet_rows
        RENAME CONSTRAINT sheet_rows_document_id_fkey TO sheet_rows_page_id_fkey;
      END IF;
    END $$;
    """

    # Rename indexes back on document_components
    execute "ALTER INDEX document_components_document_id_component_type_component_id_index RENAME TO page_components_page_id_component_type_component_id_index"
    execute "ALTER INDEX document_components_component_type_component_id_index RENAME TO page_components_component_type_component_id_index"
    execute "ALTER INDEX document_components_document_id_index RENAME TO page_components_page_id_index"

    # Rename indexes back on documents
    execute "ALTER INDEX documents_workspace_id_slug_index RENAME TO pages_workspace_id_slug_index"
    execute "ALTER INDEX documents_project_id_index RENAME TO pages_project_id_index"
    execute "ALTER INDEX documents_workspace_id_index RENAME TO pages_workspace_id_index"
    execute "ALTER INDEX documents_user_id_index RENAME TO pages_user_id_index"

    # Rename primary keys back
    execute "ALTER INDEX document_components_pkey RENAME TO page_components_pkey"
    execute "ALTER INDEX documents_pkey RENAME TO pages_pkey"

    # Rename foreign key columns back
    rename table(:sheet_rows), :document_id, to: :page_id
    rename table(:document_components), :document_id, to: :page_id

    # Rename tables back
    rename table(:document_components), to: table(:page_components)
    rename table(:documents), to: table(:pages)
  end
end
