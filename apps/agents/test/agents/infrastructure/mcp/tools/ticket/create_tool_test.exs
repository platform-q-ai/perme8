defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CreateToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.CreateTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Hermes.Server.Frame
  alias Perme8.Events.TestEventBus

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    TestEventBus.start_global()

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)
    end)

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "creates ticket locally and returns ticket number" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               CreateTool.execute(%{"title" => "New MCP Ticket", "body" => "Body"}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Created ticket #"
      assert text =~ "New MCP Ticket"
    end

    test "creates ticket with title only (no body)" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               CreateTool.execute(%{"title" => "Title Only"}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Title Only"
    end

    test "returns error for empty title" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               CreateTool.execute(%{"title" => ""}, frame)

      assert %Hermes.Server.Response{isError: true} = response
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.create" -> false end)

      assert {:reply, response, ^frame} = CreateTool.execute(%{"title" => "Nope"}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
