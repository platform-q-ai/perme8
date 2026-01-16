defmodule Jarga.Agents.Domain.AgentClonerTest do
  use ExUnit.Case, async: true

  alias Jarga.Agents.Domain.AgentCloner

  describe "clone_attrs/2" do
    test "copies all configuration fields from original agent" do
      original_agent = %{
        name: "My Agent",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "SHARED"
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      assert cloned_attrs.description == "Agent description"
      assert cloned_attrs.system_prompt == "You are a helpful assistant"
      assert cloned_attrs.model == "gpt-4"
      assert cloned_attrs.temperature == 0.7
    end

    test "appends ' (Copy)' to agent name" do
      original_agent = %{
        name: "Research Assistant",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "SHARED"
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      assert cloned_attrs.name == "Research Assistant (Copy)"
    end

    test "sets visibility to PRIVATE for cloned agent" do
      original_agent = %{
        name: "Shared Agent",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "SHARED"
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      assert cloned_attrs.visibility == "PRIVATE"
    end

    test "sets user_id to new owner" do
      original_agent = %{
        name: "My Agent",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "SHARED"
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      assert cloned_attrs.user_id == "cloner-456"
    end

    test "doesn't include workspace associations in cloned attrs" do
      original_agent = %{
        name: "My Agent",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "SHARED"
        # Note: workspace associations handled separately, not in clone_attrs
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      # Verify clone doesn't have workspace-related fields
      refute Map.has_key?(cloned_attrs, :workspace_ids)
      refute Map.has_key?(cloned_attrs, :workspaces)
    end

    test "handles agents that already have ' (Copy)' in name" do
      original_agent = %{
        name: "Agent (Copy)",
        description: "Agent description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "original-owner-123",
        visibility: "PRIVATE"
      }

      new_user_id = "cloner-456"

      cloned_attrs = AgentCloner.clone_attrs(original_agent, new_user_id)

      assert cloned_attrs.name == "Agent (Copy) (Copy)"
    end
  end
end
