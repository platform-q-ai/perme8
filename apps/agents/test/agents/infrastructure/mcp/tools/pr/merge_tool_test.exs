defmodule Agents.Infrastructure.Mcp.Tools.Pr.MergeToolTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Pr.MergeTool
  alias Agents.Pipeline
  alias Agents.Test.TicketFixtures
  alias Hermes.Server.Frame

  defmodule GitMergerStub do
    def merge(_source, _target, _method), do: :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    prev_identity = Application.get_env(:agents, :identity_module)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)

    prev_merger = Application.get_env(:agents, :pr_git_merger)
    Application.put_env(:agents, :pr_git_merger, GitMergerStub)

    {:ok, pr} =
      Pipeline.create_pull_request(
        %{
          source_branch: "feature/merge-tool",
          target_branch: "main",
          title: "Merge me",
          status: "approved"
        },
        emit_events?: false
      )

    on_exit(fn ->
      if prev_identity,
        do: Application.put_env(:agents, :identity_module, prev_identity),
        else: Application.delete_env(:agents, :identity_module)

      if prev_merger,
        do: Application.put_env(:agents, :pr_git_merger, prev_merger),
        else: Application.delete_env(:agents, :pr_git_merger)
    end)

    %{pr: pr}
  end

  test "merges pull request", %{pr: pr} do
    frame =
      Frame.new(%{
        workspace_id: "ws-1",
        user_id: "user-1",
        api_key: TicketFixtures.api_key_struct()
      })

    assert {:reply, response, ^frame} = MergeTool.execute(%{"number" => pr.number}, frame)
    assert %Hermes.Server.Response{isError: false} = response
  end
end
