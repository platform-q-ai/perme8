defmodule JargaWeb.AppLive.Agents.FormTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.AgentsFixtures

  describe "agent form read-only security guard" do
    setup %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      # Create a shared agent owned by other_user
      shared_agent =
        user_agent_fixture(%{
          user_id: other_user.id,
          name: "Shared Agent for Viewing",
          description: "Test description",
          system_prompt: "Test system prompt",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "SHARED"
        })

      %{
        conn: log_in_user(conn, user),
        user: user,
        other_user: other_user,
        shared_agent: shared_agent
      }
    end

    test "view action works without workspace context", %{
      conn: conn,
      shared_agent: shared_agent
    } do
      # This tests the bug fix where accessing /agents/:id/view directly
      # (not from within a workspace) would crash with KeyError
      {:ok, _lv, html} = live(conn, ~p"/app/agents/#{shared_agent.id}/view")

      # Should load successfully and show agent details
      assert html =~ "Shared Agent for Viewing"
      assert html =~ "Test description"
    end

    test "allows form submission when not read-only (owner editing)", %{
      conn: conn,
      user: user
    } do
      # Create agent owned by current user with all required fields
      my_agent =
        user_agent_fixture(%{
          user_id: user.id,
          name: "My Own Agent",
          description: "Original description",
          system_prompt: "Original prompt",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "PRIVATE"
        })

      # Visit edit page (not view page) - owner context
      {:ok, lv, html} = live(conn, ~p"/app/agents/#{my_agent.id}/edit")

      # Verify read_only is NOT set
      refute :sys.get_state(lv.pid).socket.assigns[:read_only]

      # Verify form HAS phx-submit (edit mode)
      assert html =~ ~r/<form[^>]*phx-submit="save"/

      # Verify inputs are NOT disabled
      refute html =~ ~r/disabled="disabled"/

      # Should be able to save (using simplified params without workspace_ids)
      lv
      |> form("form[phx-submit='save']", %{
        "agent" => %{
          "name" => "Updated Name",
          "description" => "Updated description",
          "system_prompt" => "Updated prompt",
          "model" => "gpt-4",
          "temperature" => "0.8",
          "visibility" => "PRIVATE"
        }
      })
      |> render_submit()

      # Verify agent WAS modified
      agents = Agents.list_user_agents(user.id)
      updated_agent = Enum.find(agents, &(&1.id == my_agent.id))
      assert updated_agent.name == "Updated Name"
      assert updated_agent.description == "Updated description"
    end
  end
end
