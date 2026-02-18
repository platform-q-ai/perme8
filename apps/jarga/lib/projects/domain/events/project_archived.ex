defmodule Jarga.Projects.Domain.Events.ProjectArchived do
  @moduledoc """
  Domain event emitted when a project is archived.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "project",
    fields: [project_id: nil, user_id: nil],
    required: [:project_id, :workspace_id, :user_id]
end
