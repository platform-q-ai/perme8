defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ListToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.ListTool
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
    test "returns formatted list with issue entries" do
      frame = build_frame()

      issues = [
        Fixtures.issue_map(%{number: 1, title: "First"}),
        Fixtures.issue_map(%{number: 2, title: "Second"})
      ]

      Agents.Mocks.GithubTicketClientMock
      |> expect(:list_issues, fn opts ->
        assert opts[:token] == "test-token"
        assert opts[:org] == "platform-q-ai"
        assert opts[:repo] == "perme8"
        {:ok, issues}
      end)

      assert {:reply, response, ^frame} = ListTool.execute(%{}, frame)
      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Issue"
    end

    test "passes state filter" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:list_issues, fn opts ->
        assert opts[:state] == "open"
        {:ok, []}
      end)

      ListTool.execute(%{"state" => "open"}, frame)
    end

    test "passes labels filter and includes label in output" do
      frame = build_frame()
      issues = [Fixtures.issue_map(%{number: 3, labels: ["enhancement"]})]

      Agents.Mocks.GithubTicketClientMock
      |> expect(:list_issues, fn opts ->
        assert opts[:labels] == ["enhancement"]
        {:ok, issues}
      end)

      assert {:reply, response, ^frame} = ListTool.execute(%{"labels" => ["enhancement"]}, frame)
      assert [%{"text" => text}] = response.content
      assert text =~ "enhancement"
    end

    test "passes query filter" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:list_issues, fn opts ->
        assert opts[:query] == "MCP"
        {:ok, []}
      end)

      ListTool.execute(%{"query" => "MCP"}, frame)
    end

    test "returns empty state message when no issues" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:list_issues, fn _opts -> {:ok, []} end)

      assert {:reply, response, ^frame} = ListTool.execute(%{}, frame)
      assert [%{"text" => text}] = response.content
      assert text =~ "No issues found"
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.list" -> false end)

      assert {:reply, response, ^frame} = ListTool.execute(%{}, frame)
      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "Insufficient permissions"
    end
  end
end
