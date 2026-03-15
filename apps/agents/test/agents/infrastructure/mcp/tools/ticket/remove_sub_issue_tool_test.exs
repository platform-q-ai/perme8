defmodule Agents.Infrastructure.Mcp.Tools.Ticket.RemoveSubIssueToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.RemoveSubIssueTool
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

    {:ok, _parent} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1000,
        title: "Parent",
        state: "open"
      })

    {:ok, _child} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1001,
        title: "Child",
        state: "open"
      })

    # Link child to parent
    {:ok, _} = ProjectTicketRepository.set_parent_ticket(1001, 1000)

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "removes sub-issue link" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               RemoveSubIssueTool.execute(
                 %{"parent_number" => 1000, "child_number" => 1001},
                 frame
               )

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Removed sub-issue #1001 from parent ticket #1000"
    end

    test "returns error when child not found" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               RemoveSubIssueTool.execute(
                 %{"parent_number" => 1000, "child_number" => 99999},
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
                                                                     "mcp:ticket.remove_sub_issue" ->
        false
      end)

      assert {:reply, response, ^frame} =
               RemoveSubIssueTool.execute(
                 %{"parent_number" => 1000, "child_number" => 1001},
                 frame
               )

      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
