defmodule AgentQuerySteps do
  @moduledoc """
  Agent listing and query step definitions.

  Covers:
  - Creating agents with various attributes (setup)
  - Listing and viewing agents
  - Agent count and ordering assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.AgentsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Agents
  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  # ============================================================================
  # SETUP STEPS (Data Tables)
  # ============================================================================

  step "I have created the following agents:", context do
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

    Map.put(context, :agents, agents)
  end

  step "I have no agents", context do
    user = context[:current_user]
    assert user, "User must be logged in"

    user_agents = Jarga.Agents.list_user_agents(user.id)

    assert Enum.empty?(user_agents),
           "Expected no agents for user, but found: #{length(user_agents)}"

    {:ok, Map.put(context, :agents, %{})}
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

    attrs =
      if Map.has_key?(attrs, :temperature) and is_binary(attrs.temperature) do
        {temp, _} = Float.parse(attrs.temperature)
        Map.put(attrs, :temperature, temp)
      else
        attrs
      end

    agent = agent_fixture(user, attrs)
    agents = Map.get(context, :agents, %{})

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

  step "user {string} has shared agent {string}", %{args: [user_name, agent_name]} = context do
    slug = user_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    other_user = user_fixture(%{email: "#{slug}@example.com", first_name: user_name})
    agent = agent_fixture(other_user, %{name: agent_name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})
    users = Map.get(context, :users, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:users, Map.put(users, user_name, other_user))}
  end

  step "I have two agents:", context do
    table_data = context.datatable.maps
    user = context[:current_user]

    agents =
      Enum.reduce(table_data, Map.get(context, :agents, %{}), fn row, acc ->
        enabled = row["Enabled"] == "true"

        agent =
          agent_fixture(user, %{
            name: row["Agent Name"],
            enabled: enabled,
            visibility: "SHARED"
          })

        Map.put(acc, row["Agent Name"], agent)
      end)

    Map.put(context, :agents, agents)
  end

  step "both agents are added to workspace {string}", %{args: [workspace_name]} = context do
    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        context[:current_workspace] ||
        context[:workspace]

    agents = context[:agents]

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

    other_user =
      user_fixture(%{email: "viewer_#{System.unique_integer([:positive])}@example.com"})

    add_workspace_member_fixture(workspace.id, other_user, :member)

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
    agents = context[:agents] || %{}
    actual_count = length(Map.keys(agents))
    assert actual_count == count

    {:ok, context}
  end

  step "I should see {string} with model {string}", %{args: [name, model]} = context do
    html = context[:last_html]

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
    user = context[:current_user]
    alice = get_in(context, [:users, "Alice"]) || get_in(context, [:users, "alice@example.com"])

    assert alice, "Alice must be created in a prior step"

    viewable_agents = Jarga.Agents.list_viewable_agents(user.id)
    viewable_ids = Enum.map(viewable_agents, & &1.id)

    alice_private_agents =
      Jarga.Agents.list_user_agents(alice.id)
      |> Enum.filter(&(&1.visibility == :PRIVATE))

    Enum.each(alice_private_agents, fn agent ->
      refute agent.id in viewable_ids, "Should not see Alice's private agent '#{agent.name}'"
    end)

    {:ok, context}
  end

  step "I should not see Bob's private agents", context do
    user = context[:current_user]
    bob = get_in(context, [:users, "Bob"]) || get_in(context, [:users, "bob@example.com"])

    assert bob, "Bob must be created in a prior step"

    viewable_agents = Jarga.Agents.list_viewable_agents(user.id)
    viewable_ids = Enum.map(viewable_agents, & &1.id)

    bob_private_agents =
      Jarga.Agents.list_user_agents(bob.id)
      |> Enum.filter(&(&1.visibility == :PRIVATE))

    Enum.each(bob_private_agents, fn agent ->
      refute agent.id in viewable_ids, "Should not see Bob's private agent '#{agent.name}'"
    end)

    {:ok, context}
  end

  step "the agents should be ordered: {string}, {string}, {string}",
       %{args: [first, second, third]} = context do
    agents = context[:listed_agents]
    agent_names = Enum.map(agents, & &1.name)

    first_idx = Enum.find_index(agent_names, &(&1 == first))
    second_idx = Enum.find_index(agent_names, &(&1 == second))
    third_idx = Enum.find_index(agent_names, &(&1 == third))

    assert first_idx < second_idx
    assert second_idx < third_idx

    {:ok, context}
  end

  # ============================================================================
  # DATETIME SETUP STEPS (for ordering tests)
  # ============================================================================

  step "I created agent {string} {int} days ago", %{args: [name, days]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I created agent {string} {int} day ago", %{args: [name, days]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "Alice created shared agent {string} {int} days ago",
       %{args: [name, days]} = context do
    alice =
      user_fixture(%{
        email: "alice_agent_#{System.unique_integer([:positive])}@example.com",
        first_name: "Alice"
      })

    agent = agent_fixture(alice, %{name: name, visibility: "SHARED"})

    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  alias Jarga.Agents.Infrastructure.Repositories.AgentRepository

  defp update_agent_timestamp(agent, timestamp) do
    AgentRepository.update_timestamp(agent.id, timestamp)
    {:ok, %{agent | inserted_at: timestamp}}
  end
end
