defmodule Jarga.Projects.Domain.Events.ProjectCreated do
  @moduledoc """
  Domain event emitted when a project is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "project",
    fields: [project_id: nil, user_id: nil, name: nil, slug: nil],
    required: [:project_id, :workspace_id, :user_id, :name, :slug]
end
