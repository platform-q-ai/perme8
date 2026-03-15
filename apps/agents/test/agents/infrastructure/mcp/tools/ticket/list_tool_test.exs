defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ListToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.ListTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)
    end)

    {:ok, _t1} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 500,
        title: "First ticket",
        state: "open",
        labels: ["agents"]
      })

    {:ok, _t2} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 501,
        title: "Second ticket",
        state: "closed",
        labels: ["bug"]
      })

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "lists tickets from the DB" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ListTool.execute(%{}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "First ticket"
    end

    test "filters by state" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ListTool.execute(%{"state" => "closed"}, frame)

      assert [%{"text" => text}] = response.content
      assert text =~ "Second ticket"
      refute text =~ "First ticket"
    end

    test "returns 'no tickets' when no matches" do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               ListTool.execute(%{"query" => "nonexistent999"}, frame)

      assert [%{"text" => text}] = response.content
      assert text =~ "No tickets found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.list" ->
        false
      end)

      assert {:reply, response, ^frame} = ListTool.execute(%{}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
