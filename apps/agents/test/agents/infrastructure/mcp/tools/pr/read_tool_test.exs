defmodule Agents.Infrastructure.Mcp.Tools.Pr.ReadToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Pr.ReadTool
  alias Agents.Pipeline
  alias Agents.Test.TicketFixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    {:ok, pr} =
      Pipeline.create_pull_request(%{
        source_branch: "feature/read-tool",
        target_branch: "main",
        title: "Readable PR",
        status: "open"
      })

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)
    end)

    %{pr: pr}
  end

  defp build_frame(api_key \\ TicketFixtures.api_key_struct()) do
    Frame.new(%{workspace_id: "ws-1", user_id: "user-1", api_key: api_key})
  end

  test "reads pull request by number", %{pr: pr} do
    frame = build_frame()

    assert {:reply, response, ^frame} = ReadTool.execute(%{"number" => pr.number}, frame)
    assert %Hermes.Server.Response{isError: false} = response
  end
end
