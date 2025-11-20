defmodule Jarga.Agents.Infrastructure.WorkspaceAgentJoinTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Agents.Infrastructure.Agent
  alias Jarga.Agents.Infrastructure.WorkspaceAgentJoin
  alias Jarga.Repo

  describe "WorkspaceAgentJoin schema" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, agent} =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are helpful"
        })
        |> Repo.insert()

      %{user: user, workspace: workspace, agent: agent}
    end

    test "has workspace_id and agent_id", %{workspace: workspace, agent: agent} do
      changeset =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })

      assert changeset.valid?
    end

    test "unique constraint on (workspace_id, agent_id)", %{workspace: workspace, agent: agent} do
      # Create first association
      {:ok, _} =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })
        |> Repo.insert()

      # Try to create duplicate
      changeset =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{workspace_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "foreign keys cascade delete", %{workspace: workspace, agent: agent} do
      # Create association
      {:ok, wa_join} =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })
        |> Repo.insert()

      # Delete agent
      Repo.delete!(agent)

      # Association should be cascade deleted
      refute Repo.get(WorkspaceAgentJoin, wa_join.id)
    end

    test "belongs_to associations", %{workspace: workspace, agent: agent} do
      {:ok, wa_join} =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })
        |> Repo.insert()

      # Preload associations
      wa_join = Repo.preload(wa_join, [:workspace, :agent])

      assert wa_join.workspace.id == workspace.id
      assert wa_join.agent.id == agent.id
    end
  end
end
