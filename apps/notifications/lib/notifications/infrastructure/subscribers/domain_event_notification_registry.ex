defmodule Notifications.Infrastructure.Subscribers.DomainEventNotificationRegistry do
  @moduledoc """
  Registry and templates for domain-event to notification mappings.
  """

  @mappings %{
    "identity.member_joined" => %{
      type: "workspace_member_joined",
      title: "Workspace access granted",
      recipient_strategy: :target_user
    },
    "identity.member_removed" => %{
      type: "workspace_member_removed",
      title: "Workspace access removed",
      recipient_strategy: :target_user
    },
    "projects.project_created" => %{
      type: "project_created",
      title: "Project created",
      recipient_strategy: :workspace_members_except_actor
    },
    "projects.project_updated" => %{
      type: "project_updated",
      title: "Project updated",
      recipient_strategy: :workspace_members_except_actor
    },
    "projects.project_deleted" => %{
      type: "project_deleted",
      title: "Project deleted",
      recipient_strategy: :workspace_members_except_actor
    },
    "projects.project_archived" => %{
      type: "project_archived",
      title: "Project archived",
      recipient_strategy: :workspace_members_except_actor
    },
    "documents.document_created" => %{
      type: "document_created",
      title: "Document created",
      recipient_strategy: :workspace_members_except_actor
    },
    "documents.document_title_changed" => %{
      type: "document_updated",
      title: "Document updated",
      recipient_strategy: :workspace_members_except_actor
    },
    "documents.document_deleted" => %{
      type: "document_deleted",
      title: "Document deleted",
      recipient_strategy: :workspace_members_except_actor
    }
  }

  @spec mapping_for(String.t() | nil) :: map() | nil
  def mapping_for(event_type), do: Map.get(@mappings, event_type)

  @spec supported_event_types() :: [String.t()]
  def supported_event_types, do: Map.keys(@mappings)

  @spec build_body(String.t(), map()) :: String.t()
  def build_body("identity.member_joined", event) do
    "You now have access to workspace #{fetch(event, :workspace_id)}."
  end

  def build_body("identity.member_removed", event) do
    "Your access was removed from workspace #{fetch(event, :workspace_id)}."
  end

  def build_body("projects.project_created", event) do
    "Project created: #{project_name(event)}."
  end

  def build_body("projects.project_updated", event) do
    "Project updated: #{project_name(event)}."
  end

  def build_body("projects.project_deleted", event) do
    "Project deleted (ID: #{fetch(event, :project_id)})."
  end

  def build_body("projects.project_archived", event) do
    "Project archived (ID: #{fetch(event, :project_id)})."
  end

  def build_body("documents.document_created", event) do
    "Document created: #{document_title(event)}."
  end

  def build_body("documents.document_title_changed", event) do
    "Document title updated: #{document_title(event)}."
  end

  def build_body("documents.document_deleted", event) do
    "Document deleted (ID: #{fetch(event, :document_id)})."
  end

  def build_body(_event_type, _event), do: ""

  @spec build_data(String.t(), map()) :: map()
  def build_data(event_type, event) do
    base =
      %{
        "event_type" => event_type,
        "workspace_id" => fetch(event, :workspace_id)
      }
      |> maybe_put("project_id", fetch(event, :project_id))
      |> maybe_put("project_name", fetch(event, :name))
      |> maybe_put("document_id", fetch(event, :document_id))
      |> maybe_put("document_title", fetch(event, :title))
      |> maybe_put("target_user_id", fetch(event, :target_user_id))

    Map.reject(base, fn {_k, v} -> is_nil(v) end)
  end

  defp project_name(event), do: fetch(event, :name) || fetch(event, :project_id)
  defp document_title(event), do: fetch(event, :title) || fetch(event, :document_id)

  defp fetch(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, to_string(key))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
