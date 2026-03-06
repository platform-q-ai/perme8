defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListWorkspacesToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.ListWorkspacesTool
  alias Agents.Test.JargaFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    on_exit(fn -> Application.delete_env(:agents, :identity_module) end)
    :ok
  end

  defp build_frame(workspace_id, user_id, api_key \\ %{id: "test-key", permissions: nil}) do
    Frame.new(%{workspace_id: workspace_id, user_id: user_id, api_key: api_key})
  end

  describe "execute/2" do
    test "returns formatted list of workspaces" do
      user_id = Fixtures.user_id()
      frame = build_frame(Fixtures.workspace_id(), user_id)

      workspace1 = Fixtures.workspace_map(%{name: "Alpha Workspace", slug: "alpha-workspace"})
      workspace2 = Fixtures.workspace_map(%{name: "Beta Workspace", slug: "beta-workspace"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn ^user_id -> {:ok, [workspace1, workspace2]} end)

      assert {:reply, response, ^frame} = ListWorkspacesTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Alpha Workspace"
      assert text =~ "Beta Workspace"
    end

    test "returns message when no workspaces found" do
      user_id = Fixtures.user_id()
      frame = build_frame(Fixtures.workspace_id(), user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn ^user_id -> {:ok, []} end)

      assert {:reply, response, ^frame} = ListWorkspacesTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "No workspaces found"
    end

    test "handles unexpected error" do
      user_id = Fixtures.user_id()
      frame = build_frame(Fixtures.workspace_id(), user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn ^user_id -> {:error, :timeout} end)

      assert {:reply, response, ^frame} = ListWorkspacesTool.execute(%{}, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "unexpected error"
    end

    test "denies execution when API key lacks jarga.list_workspaces scope" do
      user_id = Fixtures.user_id()
      api_key = %{id: "test-key", permissions: ["mcp:knowledge.search"]}
      frame = build_frame(Fixtures.workspace_id(), user_id, api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:jarga.list_workspaces" -> false end)

      assert {:reply, response, ^frame} = ListWorkspacesTool.execute(%{}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text == "Insufficient permissions: mcp:jarga.list_workspaces required"
    end
  end
end
