defmodule Agents.Infrastructure.Mcp.Tools.Ticket.CreateToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.CreateTool
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
    test "creates issue with title and body and returns #number" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:create_issue, fn attrs, _opts ->
        assert attrs.title == "New MCP Ticket"
        assert attrs.body == "Body"
        {:ok, Fixtures.issue_map(%{number: 123, title: "New MCP Ticket"})}
      end)

      assert {:reply, response, ^frame} =
               CreateTool.execute(%{"title" => "New MCP Ticket", "body" => "Body"}, frame)

      assert %Hermes.Server.Response{isError: false} = response
      assert [%{"text" => text}] = response.content
      assert text =~ ~r/#[0-9]+/
    end

    test "creates issue with labels" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:create_issue, fn attrs, _opts ->
        assert attrs.labels == ["enhancement"]
        {:ok, Fixtures.issue_map(%{number: 124, labels: ["enhancement"]})}
      end)

      assert {:reply, _response, ^frame} =
               CreateTool.execute(%{"title" => "With labels", "labels" => ["enhancement"]}, frame)
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.create" -> false end)

      assert {:reply, response, ^frame} = CreateTool.execute(%{"title" => "Nope"}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end
end
