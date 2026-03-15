defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CloseToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.CloseTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    prev_client = Application.get_env(:agents, :github_ticket_client)

    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    # CloseTool uses close_project_ticket which still calls GitHub client for remote close
    Application.put_env(:agents, :github_ticket_client, Agents.Mocks.GithubTicketClientMock)

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)

      if prev_client,
        do: Application.put_env(:agents, :github_ticket_client, prev_client),
        else: Application.delete_env(:agents, :github_ticket_client)
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

      # close_project_ticket calls update_issue on GitHub client first, then closes locally
      stub(Agents.Mocks.GithubTicketClientMock, :update_issue, fn _number, _attrs, _opts ->
        {:ok, %{number: 800, state: "closed"}}
      end)

      assert {:reply, response, ^frame} = CloseTool.execute(%{"number" => 800}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Closed ticket #800"
    end

    test "succeeds even when ticket doesn't exist on GitHub (treated as already closed)" do
      frame = build_frame()

      # The close facade treats GitHub :not_found as "already closed"
      stub(Agents.Mocks.GithubTicketClientMock, :update_issue, fn _number, _attrs, _opts ->
        {:error, :not_found}
      end)

      assert {:reply, response, ^frame} = CloseTool.execute(%{"number" => 99999}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Closed ticket #99999"
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
