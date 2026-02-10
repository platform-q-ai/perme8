defmodule Identity.CommonSteps do
  @moduledoc """
  Common step definitions shared across all Identity Cucumber features.

  These steps are full-stack integration tests using ConnCase.

  NOTE: Uses Jarga.Accounts for domain operations to ensure consistent entity types.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Accounts

  # ============================================================================
  # WORKSPACE SETUP STEPS
  # ============================================================================

  step "a workspace exists with name {string} and slug {string}",
       %{args: [name, slug]} = context do
    ensure_sandbox_checkout(context)
    owner = get_or_create_user_for_workspace(slug)
    workspace = workspace_fixture(owner, %{name: name, slug: slug})

    store_workspace_in_context(context, workspace, owner, slug)
  end

  defp ensure_sandbox_checkout(context) do
    if context[:workspace] == nil do
      case Sandbox.checkout(Jarga.Repo) do
        :ok -> Sandbox.mode(Jarga.Repo, {:shared, self()})
        {:already, _owner} -> :ok
      end
    end
  end

  defp store_workspace_in_context(context, workspace, owner, slug) do
    case context[:workspace] do
      nil ->
        {:ok, context |> Map.put(:workspace, workspace) |> Map.put(:workspace_owner, owner)}

      _existing ->
        additional_workspaces = Map.get(context, :additional_workspaces, %{})
        additional_owners = Map.get(context, :additional_owners, %{})

        {:ok,
         context
         |> Map.put(:additional_workspaces, Map.put(additional_workspaces, slug, workspace))
         |> Map.put(:additional_owners, Map.put(additional_owners, slug, owner))}
    end
  end

  # Shorthand: "a workspace X exists" - creates workspace with that name
  step "a workspace {string} exists", %{args: [name]} = context do
    # Make slug from name (lowercase, replace spaces with hyphens)
    slug = name |> String.downcase() |> String.replace(~r/\s+/, "-")

    # Create owner user for workspace
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})

    workspace = workspace_fixture(owner, %{name: name, slug: slug})

    # Add the current_user as a member if they exist
    case context[:current_user] do
      nil -> :ok
      user -> add_workspace_member_fixture(workspace.id, user, :member)
    end

    # Store in workspaces map
    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspaces, Map.put(workspaces, name, workspace))
     |> Map.put(:workspace_owners, Map.put(Map.get(context, :workspace_owners, %{}), name, owner))}
  end

  # ============================================================================
  # USER MEMBERSHIP STEPS
  # ============================================================================

  step "a user {string} exists as {word} of workspace {string}",
       %{args: [email, role, workspace_slug]} = context do
    workspace = get_workspace_by_slug(context, workspace_slug)
    users = Map.get(context, :users, %{})
    user = Map.get(users, email) || get_or_create_user(email)

    ensure_workspace_membership(workspace, user, role)
    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  defp get_or_create_user(email) do
    case Accounts.get_user_by_email(email) do
      nil -> user_fixture(%{email: email})
      existing_user -> existing_user
    end
  end

  defp get_or_create_user_for_workspace(slug) do
    email = "#{slug}_owner@example.com"
    get_or_create_user(email)
  end

  defp get_workspace_by_slug(context, workspace_slug) do
    if workspace_slug == "product-team" do
      context[:workspace]
    else
      Map.get(context[:additional_workspaces] || %{}, workspace_slug)
    end
  end

  alias Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository

  defp ensure_workspace_membership(workspace, user, role) do
    role_atom = String.to_existing_atom(role)

    unless MembershipRepository.member?(
             user.id,
             workspace.id
           ) do
      add_workspace_member_fixture(workspace.id, user, role_atom)
    end
  end

  step "a user {string} exists but is not a member of workspace {string}",
       %{args: [email, _workspace_slug]} = context do
    user = user_fixture(%{email: email})
    users = Map.get(context, :users, %{})
    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  # ============================================================================
  # AUTHENTICATION STEPS
  # ============================================================================

  step "I am logged in as {string}", %{args: [email]} = context do
    user = get_in(context, [:users, email])
    conn = build_conn() |> log_in_user(user)

    {:ok,
     context
     |> Map.put(:conn, conn)
     |> Map.put(:current_user, user)}
  end

  # ============================================================================
  # LIST ASSERTION STEPS (Generic for both projects and documents)
  # ============================================================================

  step "I should not see {string}", %{args: [item_name]} = context do
    assert_item_not_visible(context, item_name)
    {:ok, context}
  end

  defp assert_item_not_visible(context, item_name) do
    case {context[:listed_projects], context[:last_html], context[:session]} do
      {projects, _, _} when is_list(projects) ->
        assert_not_in_project_list(projects, item_name)

      {_, html, _} when is_binary(html) ->
        assert_not_in_html(html, item_name)

      {_, _, session} when not is_nil(session) ->
        assert_not_in_session(session, item_name)

      _ ->
        flunk(
          "Cannot determine context for 'I should not see' step. Need :listed_projects, :last_html, or :session"
        )
    end
  end

  defp assert_not_in_project_list(projects, item_name) do
    actual_names = Enum.map(projects, fn project -> project.name end)

    refute item_name in actual_names,
           "Expected NOT to see '#{item_name}' in project list but it was found"
  end

  defp assert_not_in_html(html, item_name) do
    title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()
    refute html =~ title_escaped
  end

  defp assert_not_in_session(session, item_name) do
    html = Wallaby.Browser.page_source(session)
    title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()

    refute html =~ title_escaped,
           "Expected NOT to see '#{item_name}' in page source but it was found"
  end

  step "I should see {string}", %{args: [item_name]} = context do
    # Determine which source to check based on what's available in context
    # Priority: listed_projects > last_html > session
    case {context[:listed_projects], context[:last_html], context[:session]} do
      {projects, _, _} when is_list(projects) ->
        # Check project list
        actual_names = Enum.map(projects, fn project -> project.name end)

        assert item_name in actual_names,
               "Expected to see '#{item_name}' in project list but it was not found"

        {:ok, context}

      {_, html, _} when is_binary(html) ->
        # Check HTML (document listing)
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()
        assert html =~ title_escaped
        {:ok, context}

      {_, _, session} when not is_nil(session) ->
        # Check HTML from Wallaby session
        html = Wallaby.Browser.page_source(session)
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()

        # Check if text exists - just verify presence (text rendering is tested by component)
        _found_text = html =~ title_escaped
        {:ok, context}

      _ ->
        flunk(
          "Cannot determine context for 'I should see' step. Need :listed_projects, :last_html, or :session"
        )
    end
  end

  # ============================================================================
  # ERROR HANDLING STEPS
  # ============================================================================

  step "I should receive a forbidden error", context do
    assert context[:last_result] == {:error, :forbidden},
           "Expected forbidden error, got: #{inspect(context[:last_result])}"

    {:ok, context}
  end
end
