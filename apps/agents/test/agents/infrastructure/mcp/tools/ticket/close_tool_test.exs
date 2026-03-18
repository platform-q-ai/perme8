defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CloseToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.CloseTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Hermes.Server.Frame
  alias Perme8.Events.TestEventBus

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    # TestEventBus is started for process isolation but is NOT injected into
    # the tool's opts — the real EventBus is used. This is intentional and
    # matches CreateToolTest/UpdateToolTest. The handler's rescue blocks
    # prevent crashes from async GitHub push attempts in test.
    TestEventBus.start_global()

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)
    end)

    {:ok, _ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 800,
        title: "Closable ticket",
        state: "open"
      })

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "closes a ticket" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               CloseTool.execute(%{"number" => 800}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Closed ticket #800"

      # Verify ticket is closed locally with pending_push sync state
      refreshed = Agents.Repo.get_by!(ProjectTicketSchema, number: 800)
      assert refreshed.state == "closed"
      assert refreshed.sync_state == "pending_push"
    end

    test "returns error when ticket doesn't exist locally" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               CloseTool.execute(%{"number" => 99_999}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.close" ->
        false
      end)

      assert {:reply, response, ^frame} = CloseTool.execute(%{"number" => 800}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
