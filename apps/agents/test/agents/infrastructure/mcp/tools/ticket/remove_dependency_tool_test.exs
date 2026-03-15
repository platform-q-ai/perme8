defmodule Agents.Infrastructure.Mcp.Tools.Ticket.RemoveDependencyToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.RemoveDependencyTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Agents.Tickets
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

    {:ok, blocker} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1200,
        title: "Blocker",
        state: "open"
      })

    {:ok, blocked} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1201,
        title: "Blocked",
        state: "open"
      })

    # Add dependency
    {:ok, _dep} =
      Tickets.add_dependency(blocker.id, blocked.id, actor_id: "setup", event_bus: TestEventBus)

    # Clear events from setup
    TestEventBus.start_global()

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "removes dependency between two tickets" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               RemoveDependencyTool.execute(
                 %{"blocker_number" => 1200, "blocked_number" => 1201},
                 frame
               )

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "no longer blocks"
    end

    test "returns error when dependency not found" do
      frame = build_frame()

      # Remove it first, then try again
      RemoveDependencyTool.execute(
        %{"blocker_number" => 1200, "blocked_number" => 1201},
        frame
      )

      assert {:reply, response, ^frame} =
               RemoveDependencyTool.execute(
                 %{"blocker_number" => 1200, "blocked_number" => 1201},
                 frame
               )

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.remove_dependency" ->
        false
      end)

      assert {:reply, response, ^frame} =
               RemoveDependencyTool.execute(
                 %{"blocker_number" => 1200, "blocked_number" => 1201},
                 frame
               )

      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
