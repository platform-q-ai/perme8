defmodule Chat.Application.UseCases.PrepareContextWithAgentTest do
  use ExUnit.Case, async: true

  alias Chat.Application.UseCases.PrepareContext

  describe "build_system_message_with_agent/2" do
    test "combines custom agent prompt with context" do
      agent = %{system_prompt: "You are an expert code reviewer."}

      context = %{
        current_workspace: "Engineering Team",
        current_project: "Mobile App",
        document_title: "API Documentation",
        document_content: "This document explains our REST API endpoints."
      }

      assert {:ok, message} = PrepareContext.build_system_message_with_agent(agent, context)

      assert message.role == "system"
      assert message.content =~ "expert code reviewer"
      assert message.content =~ "Engineering Team"
      assert message.content =~ "Mobile App"
      assert message.content =~ "API Documentation"
    end

    test "falls back to default when no custom prompt" do
      agent = %{system_prompt: nil}
      context = %{current_workspace: "Engineering Team", document_title: "API Documentation"}

      assert {:ok, message} = PrepareContext.build_system_message_with_agent(agent, context)
      assert message.content =~ "Perme8"
      assert message.content =~ "Engineering Team"
      assert message.content =~ "API Documentation"
    end
  end
end
