defmodule Agents.Infrastructure.Mcp.Tools.ToolsSearchToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.ToolsSearchTool
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn -> Application.delete_env(:agents, :identity_module) end)
    :ok
  end

  defp build_frame(api_key \\ %{id: "test-key", permissions: nil}) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "returns all tools when no query provided" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ToolsSearchTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "jarga.list_workspaces"
      assert text =~ "knowledge.search"
      assert text =~ "tools.search"
    end

    test "returns tools matching query by name" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ToolsSearchTool.execute(%{query: "workspace"}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "jarga.list_workspaces"
      assert text =~ "jarga.get_workspace"
      refute text =~ "knowledge.create"
    end

    test "returns no tools found for non-matching query" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ToolsSearchTool.execute(%{query: "nonexistent_xyz_tool_999"}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "No tools found"
    end

    test "groups results by provider when group_by_provider is true" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ToolsSearchTool.execute(%{group_by_provider: true}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "JargaToolProvider"
      assert text =~ "KnowledgeToolProvider"
      assert text =~ "ToolsToolProvider"
      assert text =~ "jarga.list_workspaces"
      assert text =~ "knowledge.search"
    end

    test "includes description and parameters in results" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ToolsSearchTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Description"
      assert text =~ "Parameters"
    end

    test "self-discovery: tools.search appears in own results" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ToolsSearchTool.execute(%{query: "search"}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "tools.search"
      assert text =~ "knowledge.search"
    end

    test "combined keyword and group_by_provider filter" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ToolsSearchTool.execute(%{query: "create", group_by_provider: true}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "jarga.create_project"
      assert text =~ "jarga.create_document"
      assert text =~ "knowledge.create"
    end

    test "denies execution when API key lacks tools.search scope" do
      api_key = %{id: "test-key", permissions: ["mcp:knowledge.search"]}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:tools.search" -> false end)

      assert {:reply, response, ^frame} = ToolsSearchTool.execute(%{}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text == "Insufficient permissions: mcp:tools.search required"
    end
  end
end
