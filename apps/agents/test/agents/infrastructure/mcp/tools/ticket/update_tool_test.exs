defmodule Agents.Infrastructure.Mcp.Tools.Ticket.UpdateToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.UpdateTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
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

    {:ok, _ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 700,
        title: "Original",
        state: "open"
      })

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "updates ticket title" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 700, "title" => "Updated"}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Updated ticket #700"
      assert text =~ "Updated"
    end

    test "returns error for non-existent ticket" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 99999, "title" => "Nope"}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "returns error when no updatable fields provided" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 700}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "No updatable fields"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.update" ->
        false
      end)

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 700, "title" => "Nope"}, frame)

      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
