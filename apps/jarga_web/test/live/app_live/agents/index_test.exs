defmodule JargaWeb.AppLive.Agents.IndexTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.AgentsFixtures

  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

  describe "structured event handlers" do
    setup %{conn: conn} do
      user = user_fixture()

      agent =
        user_agent_fixture(%{
          user_id: user.id,
          name: "My Agent",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "PRIVATE"
        })

      %{conn: log_in_user(conn, user), user: user, agent: agent}
    end

    test "handles AgentUpdated event by reloading agents list", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      {:ok, lv, html} = live(conn, ~p"/app/agents")

      # Verify the initial agent is shown
      assert html =~ "My Agent"

      # Update the agent name in DB so when reload happens, new name shows up
      Agents.update_user_agent(agent.id, user.id, %{"name" => "Renamed Agent"})

      event =
        AgentUpdated.new(%{
          aggregate_id: agent.id,
          actor_id: user.id,
          agent_id: agent.id,
          user_id: user.id,
          workspace_ids: [],
          changes: %{name: "Renamed Agent"}
        })

      send(lv.pid, event)

      # After event, the page should reload and show updated name
      html = render(lv)
      assert html =~ "Renamed Agent"
    end

    test "handles AgentDeleted event by reloading agents list", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/agents")

      event =
        AgentDeleted.new(%{
          aggregate_id: agent.id,
          actor_id: user.id,
          agent_id: agent.id,
          user_id: user.id,
          workspace_ids: []
        })

      send(lv.pid, event)

      assert render(lv)
    end

    test "handles AgentAddedToWorkspace event by reloading agents list", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/agents")

      event =
        AgentAddedToWorkspace.new(%{
          aggregate_id: agent.id,
          actor_id: user.id,
          agent_id: agent.id,
          user_id: user.id,
          workspace_id: Ecto.UUID.generate()
        })

      send(lv.pid, event)

      assert render(lv)
    end

    test "handles AgentRemovedFromWorkspace event by reloading agents list", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/agents")

      event =
        AgentRemovedFromWorkspace.new(%{
          aggregate_id: agent.id,
          actor_id: user.id,
          agent_id: agent.id,
          user_id: user.id,
          workspace_id: Ecto.UUID.generate()
        })

      send(lv.pid, event)

      assert render(lv)
    end
  end
end
