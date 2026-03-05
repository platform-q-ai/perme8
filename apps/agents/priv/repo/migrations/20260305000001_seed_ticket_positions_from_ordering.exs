defmodule Agents.Repo.Migrations.SeedTicketPositionsFromOrdering do
  use Ecto.Migration

  @doc """
  Seeds position values for existing tickets that all have position=0 after the
  position column was added. Orders tickets by priority, size, then inserted_at
  (matching the app's tiebreaker ordering) and assigns sequential positions.
  """
  def up do
    execute("""
    WITH ordered AS (
      SELECT id,
             ROW_NUMBER() OVER (
               ORDER BY
                 CASE priority
                   WHEN 'Need' THEN 0
                   WHEN 'Want' THEN 1
                   WHEN 'Nice to have' THEN 2
                   ELSE 3
                 END ASC,
                 CASE size
                   WHEN 'XL' THEN 0
                   WHEN 'L' THEN 1
                   WHEN 'M' THEN 2
                   WHEN 'S' THEN 3
                   WHEN 'XS' THEN 4
                   ELSE 5
                 END ASC,
                 inserted_at DESC
             ) - 1 AS new_position
      FROM sessions_project_tickets
      WHERE position = 0
    )
    UPDATE sessions_project_tickets
    SET position = ordered.new_position
    FROM ordered
    WHERE sessions_project_tickets.id = ordered.id
    """)
  end

  def down do
    execute("UPDATE sessions_project_tickets SET position = 0")
  end
end
