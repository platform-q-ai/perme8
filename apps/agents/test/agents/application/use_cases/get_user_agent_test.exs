defmodule Agents.Application.UseCases.GetUserAgentTest do
  use Jarga.DataCase, async: true

  alias Agents.Application.UseCases.GetUserAgent
  alias Agents.Infrastructure.Schemas.AgentSchema
  alias Agents.Test.AccountsFixtures

  setup do
    user = AccountsFixtures.user_fixture()

    {:ok, agent} =
      Identity.Repo.insert(
        AgentSchema.changeset(%AgentSchema{}, %{
          user_id: user.id,
          name: "Test Agent"
        })
      )

    {:ok, user: user, agent: agent}
  end

  describe "execute/2" do
    test "returns {:ok, agent} when agent belongs to user", %{user: user, agent: agent} do
      assert {:ok, found_agent} = GetUserAgent.execute(agent.id, user.id)
      assert found_agent.id == agent.id
      assert found_agent.name == "Test Agent"
    end

    test "returns {:error, :not_found} when agent does not exist", %{user: user} do
      assert {:error, :not_found} = GetUserAgent.execute(Ecto.UUID.generate(), user.id)
    end

    test "returns {:error, :not_found} when agent belongs to another user", %{agent: agent} do
      other_user = AccountsFixtures.user_fixture()
      assert {:error, :not_found} = GetUserAgent.execute(agent.id, other_user.id)
    end
  end
end
