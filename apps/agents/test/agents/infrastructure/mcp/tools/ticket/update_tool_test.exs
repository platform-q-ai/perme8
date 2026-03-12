defmodule Agents.Infrastructure.Mcp.Tools.Ticket.UpdateToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Ticket.UpdateTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_client = Application.get_env(:agents, :github_ticket_client)
    prev_identity = Application.get_env(:agents, :identity_module)
    prev_sessions = Application.get_env(:agents, :sessions)

    Application.put_env(:agents, :github_ticket_client, Agents.Mocks.GithubTicketClientMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    Application.put_env(:agents, :sessions,
      github_token: "test-token",
      github_org: "platform-q-ai",
      github_repo: "perme8"
    )

    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    on_exit(fn ->
      restore_or_delete(:agents, :github_ticket_client, prev_client)
      restore_or_delete(:agents, :identity_module, prev_identity)
      restore_or_delete(:agents, :sessions, prev_sessions)
    end)

    :ok
  end

  defp build_frame(api_key \\ Fixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  describe "execute/2" do
    test "updates issue title" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:update_issue, fn 44, attrs, _opts ->
        assert attrs == %{title: "Renamed"}
        {:ok, Fixtures.issue_map(%{number: 44, title: "Renamed"})}
      end)

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 44, "title" => "Renamed"}, frame)

      assert %Hermes.Server.Response{isError: false} = response
    end

    test "returns not found for unknown issue" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:update_issue, fn 404, _attrs, _opts -> {:error, :not_found} end)

      assert {:reply, response, ^frame} =
               UpdateTool.execute(%{"number" => 404, "title" => "x"}, frame)

      assert %Hermes.Server.Response{isError: true} = response
      assert [%{"text" => text}] = response.content
      assert text =~ "not found"
    end

    test "omitted fields are unchanged while explicit empty list clears" do
      frame = build_frame()

      Agents.Mocks.GithubTicketClientMock
      |> expect(:update_issue, fn 45, attrs, _opts ->
        assert attrs == %{labels: []}
        {:ok, Fixtures.issue_map(%{number: 45, labels: []})}
      end)

      assert {:reply, _response, ^frame} =
               UpdateTool.execute(%{"number" => 45, "labels" => []}, frame)
    end

    test "denies execution when scope is missing" do
      api_key = %{id: "k-1", permissions: []}
      frame = build_frame(api_key)

      Agents.Mocks.IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:ticket.update" -> false end)

      assert {:reply, response, ^frame} = UpdateTool.execute(%{"number" => 1}, frame)
      assert %Hermes.Server.Response{isError: true} = response
    end
  end

  defp restore_or_delete(app, key, nil), do: Application.delete_env(app, key)
  defp restore_or_delete(app, key, value), do: Application.put_env(app, key, value)
end
