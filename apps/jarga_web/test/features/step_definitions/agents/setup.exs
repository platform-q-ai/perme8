defmodule AgentSetupSteps do
  @moduledoc """
  Setup and background step definitions for Agent feature scenarios.

  Covers:
  - Sandbox checkout (first Background step)
  - User login and authentication
  - Navigation to agent pages
  - Workspace setup for agents
  - Other user setup
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Accounts

  # ============================================================================
  # BACKGROUND SETUP STEPS (Sandbox checkout)
  # ============================================================================

  step "I am logged in as a user", context do
    checkout_sandbox()

    # Reuse existing user and conn if already logged in
    user = context[:current_user] || user_fixture()
    conn = context[:conn] || build_conn() |> log_in_user(user)

    existing_users = context[:users] || %{}

    {:ok,
     context
     |> Map.put(:sandbox_checked_out, true)
     |> Map.put(:conn, conn)
     |> Map.put(:current_user, user)
     |> Map.put(:users, Map.put(existing_users, user.email, user))}
  end

  defp checkout_sandbox do
    case Sandbox.checkout(Jarga.Repo) do
      :ok -> Sandbox.mode(Jarga.Repo, {:shared, self()})
      {:already, :owner} -> :ok
    end
  end

  # ============================================================================
  # NAVIGATION STEPS
  # ============================================================================

  step "I navigate to the agents page", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/agents")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I navigate to the new agent page", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/agents/new")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I open the chat panel with a test document", context do
    workspace = context[:current_workspace] || context[:workspace]
    user = context[:current_user]
    conn = context[:conn]

    document = create_test_document(user, workspace)
    {view, html} = navigate_to_document(conn, workspace, document)
    context = auto_select_agent_if_needed(context, user, workspace)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)}
  end

  defp create_test_document(user, workspace) do
    document_fixture(user, workspace, nil, %{
      title: "Chat Test Document",
      content: "Test content for chat"
    })
  end

  defp navigate_to_document(conn, workspace, document) do
    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {view, html}
  end

  defp auto_select_agent_if_needed(context, user, workspace) do
    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)

    if is_nil(saved_agent_id) do
      select_first_available_agent(context, user, workspace)
    else
      context
    end
  end

  defp select_first_available_agent(context, user, workspace) do
    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])

    case List.first(all_agents) do
      nil ->
        context

      first_agent ->
        {:ok, _} = Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, first_agent.id)
        Map.put(context, :auto_selected_agent, first_agent)
    end
  end

  # ============================================================================
  # WORKSPACE SETUP STEPS
  # ============================================================================

  step "I have a workspace named {string}", %{args: [name]} = context do
    user = context[:current_user]
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    workspace = workspace_fixture(user, %{name: name, slug: slug})

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:workspaces, Map.put(workspaces, name, workspace))}
  end

  step "there is a workspace named {string}", %{args: [name]} = context do
    other_user =
      user_fixture(%{email: "workspace_owner_#{System.unique_integer([:positive])}@example.com"})

    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    workspace = workspace_fixture(other_user, %{name: name, slug: slug})

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspaces, Map.put(workspaces, name, workspace))}
  end

  step "I am a member of workspace {string}", %{args: [workspace_name]} = context do
    user = context[:current_user]

    {workspace, updated_context} =
      get_or_create_workspace_for_member(context, workspace_name, user)

    {:ok, Map.put(updated_context, :current_workspace, workspace)}
  end

  defp get_or_create_workspace_for_member(context, workspace_name, user) do
    existing = get_in(context, [:workspaces, workspace_name])

    workspace = existing || create_workspace_with_owner(workspace_name)

    try do
      add_workspace_member_fixture(workspace.id, user, :member)
    rescue
      Ecto.InvalidChangesetError -> :ok
    end

    workspaces = Map.get(context, :workspaces, %{})
    {workspace, Map.put(context, :workspaces, Map.put(workspaces, workspace_name, workspace))}
  end

  defp create_workspace_with_owner(workspace_name) do
    slug = workspace_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    owner = user_fixture(%{email: "#{slug}-owner@example.com"})
    workspace_fixture(owner, %{name: workspace_name, slug: slug})
  end

  step "I am not a member of workspace {string}", %{args: [workspace_name]} = context do
    user = context[:current_user]

    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        create_workspace_with_owner(workspace_name)

    memberships = Jarga.Workspaces.list_workspaces_for_user(user)
    member_ids = Enum.map(memberships, & &1.id)

    assert workspace.id not in member_ids,
           "User should NOT be a member of workspace '#{workspace_name}'"

    workspaces = Map.get(context, :workspaces, %{})

    {:ok, Map.put(context, :workspaces, Map.put(workspaces, workspace_name, workspace))}
  end

  step "I navigate to workspace {string} settings", %{args: [workspace_name]} = context do
    workspace = get_in(context, [:workspaces, workspace_name]) || context[:workspace]
    conn = context[:conn]

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/edit")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am in workspace {string}", %{args: [workspace_name]} = context do
    user = context[:current_user]

    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        context[:workspace] ||
        create_workspace_for_user(workspace_name, user)

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:workspaces, Map.put(workspaces, workspace_name, workspace))}
  end

  defp create_workspace_for_user(workspace_name, user) do
    slug = workspace_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    workspace_fixture(user, %{name: workspace_name, slug: slug})
  end

  step "I navigate back to workspace {string}", %{args: [workspace_name]} = context do
    user = context[:current_user]
    conn = context[:conn]

    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        create_workspace_for_user(workspace_name, user)

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:workspaces, Map.put(workspaces, workspace_name, workspace))}
  end

  step "I am viewing workspace {string}", %{args: [workspace_name]} = context do
    user = context[:current_user]
    conn = context[:conn]

    workspace =
      get_in(context, [:workspaces, workspace_name]) ||
        create_workspace_for_user(workspace_name, user)

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:workspaces, Map.put(workspaces, workspace_name, workspace))}
  end

  step "I am a member of workspaces {string} and {string}",
       %{args: [workspace1, workspace2]} = context do
    user = context[:current_user]

    slug1 = workspace1 |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    slug2 = workspace2 |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")

    ws1 = workspace_fixture(user, %{name: workspace1, slug: slug1})
    ws2 = workspace_fixture(user, %{name: workspace2, slug: slug2})

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspace, ws1)
     |> Map.put(:workspaces, workspaces |> Map.put(workspace1, ws1) |> Map.put(workspace2, ws2))}
  end

  # ============================================================================
  # OTHER USER STEPS
  # ============================================================================

  step "another user is {string}", %{args: [name]} = context do
    email = "#{String.downcase(name)}@example.com"

    other_user =
      case Accounts.get_user_by_email(email) do
        nil -> user_fixture(%{email: email, first_name: name})
        existing_user -> existing_user
      end

    users = Map.get(context, :users, %{})

    {:ok,
     context
     |> Map.put(:users, Map.put(users, name, other_user))
     |> Map.put(:other_user, other_user)}
  end
end
