defmodule Agents.Infrastructure.Mcp.Tools.Pr.ReviewToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Pr.ReviewTool
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
        source_branch: "feature/review-tool",
        target_branch: "main",
        title: "Review me",
        status: "in_review"
      })

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)
    end)

    %{pr: pr}
  end

  test "submits approve review", %{pr: pr} do
    frame =
      Frame.new(%{
        workspace_id: "ws-1",
        user_id: "user-1",
        api_key: TicketFixtures.api_key_struct()
      })

    assert {:reply, response, ^frame} =
             ReviewTool.execute(%{"number" => pr.number, "event" => "approve"}, frame)

    assert %Hermes.Server.Response{isError: false} = response
  end
end
