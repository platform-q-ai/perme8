defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool
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

    {:ok, _ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 600,
        title: "Readable ticket",
        body: "This is the body.",
        state: "open",
        labels: ["agents"]
      })

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "reads a ticket by number from the DB" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 600}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Ticket #600"
      assert text =~ "Readable ticket"
      assert text =~ "This is the body."
    end

    test "returns error for non-existent ticket" do
      frame = build_frame()

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 99_999}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key,
                                                                     "mcp:ticket.read" ->
        false
      end)

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 600}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
