defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool
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
    test "returns formatted issue details" do
      frame = build_frame()

      issue =
        Fixtures.issue_map(%{
          number: 42,
          title: "Ticket MCP integration",
          state: "open",
          labels: ["enhancement", "mcp"],
          assignees: ["alice"],
          comments: [Fixtures.comment_map(%{body: "first comment"})],
          sub_issue_numbers: [100, 101]
        })

      Agents.Mocks.GithubTicketClientMock
      |> expect(:get_issue, fn 42, opts ->
        assert opts[:token] == "test-token"
        assert opts[:org] == "platform-q-ai"
        assert opts[:repo] == "perme8"
        {:ok, issue}
      end)

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 42}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Title"
      assert text =~ "Labels"
      assert text =~ "State"
      assert text =~ "Sub-issues"
      assert text =~ "Comments"
    end

    test "returns not found error for unknown issue" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:get_issue, fn 999, _opts -> {:error, :not_found} end)

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 999}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "not found"
    end

    test "denies execution when api key lacks mcp:ticket.read scope" do
      api_key = %{id: "key-1", permissions: ["mcp:tools.search"]}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.read" -> false end)

      assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => 1}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Insufficient permissions"
      assert text =~ "mcp:ticket.read"
    end
  end
end
