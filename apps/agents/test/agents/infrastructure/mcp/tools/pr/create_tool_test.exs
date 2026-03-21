defmodule Agents.Infrastructure.Mcp.Tools.Pr.CreateToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Pr.CreateTool
  alias Agents.Test.TicketFixtures
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

    :ok
  end

  defp build_frame(api_key \\ TicketFixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  test "creates internal pull request" do
    frame = build_frame()

    assert {:reply, response, ^frame} =
             CreateTool.execute(
               %{
                 "source_branch" => "feature/create-tool",
                 "target_branch" => "main",
                 "title" => "Create tool PR"
               },
               frame
             )

    assert %Hermes.Server.Response{isError: false} = response
  end

  test "denies when permission missing" do
    api_key = %{id: "k-1", permissions: []}
    frame = build_frame(api_key)

    expect(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn ^api_key, "mcp:pr.create" ->
      false
    end)

    assert {:reply, response, ^frame} = CreateTool.execute(%{"title" => "Nope"}, frame)
    assert %Hermes.Server.Response{isError: true} = response
  end
end
