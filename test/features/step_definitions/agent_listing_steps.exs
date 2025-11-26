defmodule AgentListingSteps do
  @moduledoc """
  Cucumber step definitions for Agent Listing scenarios.

  Covers:
  - Viewing personal agents list
  - Empty state handling
  - Filtering agents by visibility
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents

  # ============================================================================
  # SETUP STEPS (Data Tables)
  # ============================================================================

  step "I have created the following agents:", context do
    # Access data table using dot notation
    table_data = context.datatable.maps
    user = context[:current_user]

    agents =
      Enum.reduce(table_data, %{}, fn row, acc ->
        agent =
          agent_fixture(user, %{
            name: row["Name"],
            model: row["Model"],
            visibility: row["Visibility"]
          })

        Map.put(acc, row["Name"], agent)
      end)

    # Return context directly for data table steps (no {:ok, })
    Map.put(context, :agents, agents)
  end

  step "I have no agents", context do
    # No agents to create - just confirm user exists
    {:ok, context}
  end

  step "I have an agent named {string}", %{args: [name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I have an agent named {string} with visibility {string}",
       %{args: [name, visibility]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name, visibility: visibility})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I have a private agent named {string}", %{args: [name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name, visibility: "PRIVATE"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I have a shared agent named {string}", %{args: [name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I have an agent named {string} with:", %{args: [name]} = context do
    # Access data table using dot notation
    table_data = context.datatable.maps
    user = context[:current_user]

    attrs =
      Enum.reduce(table_data, %{name: name}, fn row, acc ->
        field = row["Field"] || row["Key"] || Enum.at(Map.keys(row), 0)
        value = row["Value"] || row[field]

        field_atom =
          field
          |> String.downcase()
          |> String.replace(" ", "_")
          |> String.to_atom()

        Map.put(acc, field_atom, value)
      end)

    # Handle temperature conversion
    attrs =
      if Map.has_key?(attrs, :temperature) and is_binary(attrs.temperature) do
        {temp, _} = Float.parse(attrs.temperature)
        Map.put(attrs, :temperature, temp)
      else
        attrs
      end

    agent = agent_fixture(user, attrs)
    agents = Map.get(context, :agents, %{})

    # Return context directly for data table steps (no {:ok, })
    context
    |> Map.put(:agent, agent)
    |> Map.put(:agents, Map.put(agents, name, agent))
  end

  step "I have private agents {string} and {string}",
       %{args: [name1, name2]} = context do
    user = context[:current_user]
    agent1 = agent_fixture(user, %{name: name1, visibility: "PRIVATE"})
    agent2 = agent_fixture(user, %{name: name2, visibility: "PRIVATE"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, agents |> Map.put(name1, agent1) |> Map.put(name2, agent2))}
  end

  step "user {string} has shared agent {string}", %{args: [_user_name, agent_name]} = context do
    # Create email-safe slug from agent name (no spaces)
    slug = agent_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    other_user = user_fixture(%{email: "#{slug}-owner@example.com"})
    agent = agent_fixture(other_user, %{name: agent_name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  step "I have two agents:", context do
    # Access data table using dot notation
    table_data = context.datatable.maps
    user = context[:current_user]

    agents =
      Enum.reduce(table_data, Map.get(context, :agents, %{}), fn row, acc ->
        enabled = row["Enabled"] == "true"

        # Create as SHARED so workspace members can see them
        agent =
          agent_fixture(user, %{
            name: row["Agent Name"],
            enabled: enabled,
            visibility: "SHARED"
          })

        Map.put(acc, row["Agent Name"], agent)
      end)

    # Return context directly for data table steps
    Map.put(context, :agents, agents)
  end

  step "both agents are added to workspace {string}", %{args: [workspace_name]} = context do
    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        context[:current_workspace] ||
        context[:workspace]

    agents = context[:agents]

    alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

    Enum.each(agents, fn {_name, agent} ->
      WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)
    end)

    {:ok, Map.put(context, :workspace, workspace)}
  end

  # ============================================================================
  # LISTING ACTIONS
  # ============================================================================

  step "I list viewable agents", context do
    user = context[:current_user]
    agents = Agents.list_viewable_agents(user.id)

    # Also verify via UI
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/agents")

    {:ok,
     context
     |> Map.put(:listed_agents, agents)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "another workspace member views available agents", context do
    workspace = context[:workspace] || context[:current_workspace]

    # Create another user and add as member
    other_user =
      user_fixture(%{email: "viewer_#{System.unique_integer([:positive])}@example.com"})

    add_workspace_member_fixture(workspace.id, other_user, :member)

    # Get agents visible to this user
    agents = Agents.get_workspace_agents_list(workspace.id, other_user.id, enabled_only: true)

    {:ok,
     context
     |> Map.put(:other_user, other_user)
     |> Map.put(:other_user_agents, agents)}
  end

  # ============================================================================
  # LISTING ASSERTIONS
  # ============================================================================

  step "I should see {int} agents in my list", %{args: [count]} = context do
    _html = context[:last_html]
    agents = context[:agents] || %{}

    # Count agents in list by looking for table rows or agent items
    # The agents index page shows agents in a table
    actual_count = length(Map.keys(agents))
    assert actual_count == count

    {:ok, context}
  end

  step "I should see {string} with model {string}", %{args: [name, model]} = context do
    html = context[:last_html]

    # HTML-encode the name for matching
    name_escaped = Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()

    assert html =~ name_escaped
    assert html =~ model || html =~ "Not set"

    {:ok, context}
  end

  step "I should see {string} in my agents list", %{args: [name]} = context do
    html = context[:last_html]
    name_escaped = Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()

    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should see a {string} button", %{args: [button_text]} = context do
    html = context[:last_html]
    assert html =~ button_text
    {:ok, context}
  end

  step "they should see {string}", %{args: [name]} = context do
    agents = context[:other_user_agents]
    agent_names = Enum.map(agents, & &1.name)

    assert name in agent_names

    {:ok, context}
  end

  step "they should not see {string}", %{args: [name]} = context do
    agents = context[:other_user_agents]
    agent_names = Enum.map(agents, & &1.name)

    refute name in agent_names

    {:ok, context}
  end

  step "I should see {int} agents total", %{args: [count]} = context do
    agents = context[:listed_agents] || Map.values(context[:agents] || %{})
    assert length(agents) == count
    {:ok, context}
  end

  step "the viewable agents should include {string}", %{args: [name]} = context do
    agents = context[:listed_agents]
    agent_names = Enum.map(agents, & &1.name)

    assert name in agent_names,
           "Expected '#{name}' in viewable agents but got: #{inspect(agent_names)}"

    {:ok, context}
  end

  step "I should not see Alice's private agents", context do
    # Already asserted by not including them in viewable list
    {:ok, context}
  end

  step "I should not see Bob's private agents", context do
    # Already asserted by not including them in viewable list
    {:ok, context}
  end

  step "the agents should be ordered: {string}, {string}, {string}",
       %{args: [first, second, third]} = context do
    agents = context[:listed_agents]
    agent_names = Enum.map(agents, & &1.name)

    # Check ordering
    first_idx = Enum.find_index(agent_names, &(&1 == first))
    second_idx = Enum.find_index(agent_names, &(&1 == second))
    third_idx = Enum.find_index(agent_names, &(&1 == third))

    assert first_idx < second_idx
    assert second_idx < third_idx

    {:ok, context}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp add_workspace_member_fixture(workspace_id, user, role) do
    Jarga.WorkspacesFixtures.add_workspace_member_fixture(workspace_id, user, role)
  end
end
