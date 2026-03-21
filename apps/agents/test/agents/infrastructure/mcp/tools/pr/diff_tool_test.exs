defmodule Agents.Infrastructure.Mcp.Tools.Pr.DiffToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Pr.DiffTool
  alias Agents.Pipeline
  alias Agents.Test.TicketFixtures
  alias Hermes.Server.Frame

  defmodule DiffComputerStub do
    def compute_diff(_source, _target), do: {:ok, "diff --git a/x b/x"}
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    prev_diff = Application.get_env(:agents, :pr_diff_computer)
    Application.put_env(:agents, :pr_diff_computer, DiffComputerStub)

    {:ok, pr} =
      Pipeline.create_pull_request(%{
        source_branch: "feature/diff-tool",
        target_branch: "main",
        title: "Diff me"
      })

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)

      if prev_diff,
        do: Application.put_env(:agents, :pr_diff_computer, prev_diff),
        else: Application.delete_env(:agents, :pr_diff_computer)
    end)

    %{pr: pr}
  end

  test "returns pull request diff", %{pr: pr} do
    frame =
      Frame.new(%{
        workspace_id: "ws-1",
        user_id: "user-1",
        api_key: TicketFixtures.api_key_struct()
      })

    assert {:reply, response, ^frame} = DiffTool.execute(%{"number" => pr.number}, frame)
    assert %Hermes.Server.Response{isError: false} = response
  end
end
