defmodule Agents.Repo.Migrations.BackfillSessionsFromTasks do
  use Ecto.Migration

  def up do
    # Create session records from tasks grouped by container_id.
    # For tasks with a container_id, group them and create a session per
    # unique (container_id, user_id) pair.
    execute("""
    INSERT INTO sessions (id, user_id, title, status, container_id, container_port,
                          container_status, image, sdk_session_id, inserted_at, updated_at)
    SELECT
      gen_random_uuid() AS id,
      t.user_id,
      (SELECT st.instruction FROM sessions_tasks st
       WHERE st.container_id = t.container_id AND st.user_id = t.user_id
       ORDER BY st.inserted_at ASC LIMIT 1) AS title,
      CASE
        WHEN EXISTS (
          SELECT 1 FROM sessions_tasks st
          WHERE st.container_id = t.container_id AND st.user_id = t.user_id
          AND st.status IN ('running', 'pending', 'starting', 'queued', 'awaiting_feedback')
        ) THEN 'active'
        WHEN EXISTS (
          SELECT 1 FROM sessions_tasks st
          WHERE st.container_id = t.container_id AND st.user_id = t.user_id
          AND st.status = 'failed'
          AND NOT EXISTS (
            SELECT 1 FROM sessions_tasks st2
            WHERE st2.container_id = t.container_id AND st2.user_id = t.user_id
            AND st2.status = 'completed'
          )
        ) THEN 'failed'
        ELSE 'completed'
      END AS status,
      t.container_id,
      MAX(t.container_port) AS container_port,
      CASE
        WHEN EXISTS (
          SELECT 1 FROM sessions_tasks st
          WHERE st.container_id = t.container_id AND st.user_id = t.user_id
          AND st.status IN ('running', 'starting', 'pending')
        ) THEN 'running'
        ELSE 'stopped'
      END AS container_status,
      (SELECT st.image FROM sessions_tasks st
       WHERE st.container_id = t.container_id AND st.user_id = t.user_id
       ORDER BY st.inserted_at ASC LIMIT 1) AS image,
      (SELECT st.session_id FROM sessions_tasks st
       WHERE st.container_id = t.container_id AND st.user_id = t.user_id
       AND st.session_id IS NOT NULL
       ORDER BY st.updated_at DESC LIMIT 1) AS sdk_session_id,
      MIN(t.inserted_at) AS inserted_at,
      MAX(t.updated_at) AS updated_at
    FROM sessions_tasks t
    WHERE t.container_id IS NOT NULL
    GROUP BY t.container_id, t.user_id
    """)

    # Link tasks to their newly created sessions
    execute("""
    UPDATE sessions_tasks
    SET session_ref_id = s.id
    FROM sessions s
    WHERE sessions_tasks.container_id = s.container_id
    AND sessions_tasks.user_id = s.user_id
    AND sessions_tasks.container_id IS NOT NULL
    """)

    # Create synthetic sessions for tasks without container_id
    execute("""
    INSERT INTO sessions (id, user_id, title, status, container_status, image,
                          inserted_at, updated_at)
    SELECT
      gen_random_uuid() AS id,
      t.user_id,
      t.instruction AS title,
      CASE
        WHEN t.status IN ('queued', 'pending') THEN 'active'
        WHEN t.status = 'failed' THEN 'failed'
        WHEN t.status = 'cancelled' THEN 'completed'
        ELSE 'completed'
      END AS status,
      'pending' AS container_status,
      COALESCE(t.image, 'perme8-opencode') AS image,
      t.inserted_at,
      t.updated_at
    FROM sessions_tasks t
    WHERE t.container_id IS NULL
    AND t.session_ref_id IS NULL
    """)

    # Link orphan tasks to their synthetic sessions (matched by user_id + instruction + timestamps)
    execute("""
    UPDATE sessions_tasks
    SET session_ref_id = s.id
    FROM sessions s
    WHERE sessions_tasks.container_id IS NULL
    AND sessions_tasks.session_ref_id IS NULL
    AND sessions_tasks.user_id = s.user_id
    AND sessions_tasks.instruction = s.title
    AND sessions_tasks.inserted_at = s.inserted_at
    """)
  end

  def down do
    execute("UPDATE sessions_tasks SET session_ref_id = NULL")
    execute("DELETE FROM sessions")
  end
end
