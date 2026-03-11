defmodule Agents.Sessions.Domain.Events.SessionFileEdited do
  @moduledoc """
  Domain event emitted when the session edits a file.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      file_path: nil,
      edit_summary: nil
    ],
    required: [:task_id, :file_path]
end
