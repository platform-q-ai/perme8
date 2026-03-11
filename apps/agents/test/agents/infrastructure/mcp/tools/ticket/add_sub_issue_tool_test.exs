defmodule Agents.Infrastructure.Mcp.Tools.Ticket.AddSubIssueToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.AddSubIssueTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :github_ticket_client, Agents.Mocks.GithubTicketClientMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    Application.put_env(:agents, :sessions,
      github_token: "test-token",
      github_org: "platform-q-ai",
      github_repo: "perme8"
    )

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn ->
      Application.delete_env(:agents, :github_ticket_client)
      Application.delete_env(:agents, :identity_module)
      Application.delete_env(:agents, :sessions)
    end)

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "adds sub-issue link and returns success" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:add_sub_issue, fn 1, 2, _opts -> {:ok, %{parent_number: 1, child_number: 2}} end)

      assert {:reply, response, ^frame} =
               AddSubIssueTool.execute(%{"parent_number" => 1, "child_number" => 2}, frame)

      assert %Hermes.Server.Response{isError: false} = response
    end

    test "returns not found error when issue does not exist" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:add_sub_issue, fn 1, 999, _opts -> {:error, :not_found} end)

      assert {:reply, response, ^frame} =
               AddSubIssueTool.execute(%{"parent_number" => 1, "child_number" => 999}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "returns generic error for api rejection" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:add_sub_issue, fn 1, 999, _opts ->
        {:error, "Unable to modify sub-issue relationship: Not Found"}
      end)

      assert {:reply, response, ^frame} =
               AddSubIssueTool.execute(%{"parent_number" => 1, "child_number" => 999}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "unexpected error"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.add_sub_issue" -> false end)

      assert {:reply, response, ^frame} =
               AddSubIssueTool.execute(%{"parent_number" => 1, "child_number" => 2}, frame)

      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
