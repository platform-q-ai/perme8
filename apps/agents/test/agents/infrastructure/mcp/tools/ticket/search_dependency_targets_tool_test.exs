defmodule Agents.Infrastructure.Mcp.Tools.Ticket.SearchDependencyTargetsToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.SearchDependencyTargetsTool
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

    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1300,
        title: "Searchable ticket",
        state: "open"
      })

    {:ok, _other} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 1301,
        title: "Another ticket",
        state: "open"
      })

    %{ticket: ticket}
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "searches tickets by title", %{ticket: ticket} do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               SearchDependencyTargetsTool.execute(
                 %{"query" => "Searchable", "exclude_ticket_id" => ticket.id + 100},
                 frame
               )

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Ticket #1300"
      assert text =~ "Searchable ticket"
    end

    test "returns no matches message when nothing found", %{ticket: ticket} do
      frame = build_frame()

      assert {:reply, response, ^frame} =
               SearchDependencyTargetsTool.execute(
                 %{"query" => "nonexistent", "exclude_ticket_id" => ticket.id},
                 frame
               )

      assert [%{"text" => text}] = response.content
      assert text =~ "No matching tickets found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.search_dependency_targets" ->
        false
      end)

      assert {:reply, response, ^frame} =
               SearchDependencyTargetsTool.execute(
                 %{"query" => "test", "exclude_ticket_id" => 1},
                 frame
               )

      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
