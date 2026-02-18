defmodule Jarga.Projects.Domain.Events.ProjectUpdated do
  @moduledoc """
  Domain event emitted when a project is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "project",
    fields: [project_id: nil, user_id: nil, name: nil, changes: %{}],
    required: [:project_id, :workspace_id, :user_id]
end
