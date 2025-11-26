defmodule CommonSteps do
  @moduledoc """
  Common step definitions shared across all Cucumber features.

  These steps are full-stack integration tests using ConnCase.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # WORKSPACE SETUP STEPS
  # ============================================================================

  step "a workspace exists with name {string} and slug {string}",
       %{args: [name, slug]} = context do
    # Only checkout sandbox if not already checked out (first workspace in Background)
    unless context[:workspace] do
      # Handle both :ok and {:already, _owner} returns from checkout
      case Sandbox.checkout(Jarga.Repo) do
        :ok ->
          Sandbox.mode(Jarga.Repo, {:shared, self()})

        {:already, _owner} ->
          :ok
      end
    end

    # Create owner user for workspace
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})

    workspace = workspace_fixture(owner, %{name: name, slug: slug})

    # If this is the first workspace (Background), set as primary
    # If this is a second workspace, store separately
    if context[:workspace] do
      # Store as additional workspace
      additional_workspaces = Map.get(context, :additional_workspaces, %{})

      {:ok,
       context
       |> Map.put(:additional_workspaces, Map.put(additional_workspaces, slug, workspace))
       |> Map.put(
         :additional_owners,
         Map.put(Map.get(context, :additional_owners, %{}), slug, owner)
       )}
    else
      # First workspace - set as primary
      {:ok,
       context
       |> Map.put(:workspace, workspace)
       |> Map.put(:workspace_owner, owner)}
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
    if context[:current_user] do
      add_workspace_member_fixture(workspace.id, context[:current_user], :member)
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
    # Get the workspace from context (could be primary or additional)
    workspace =
      if workspace_slug == "product-team" do
        context[:workspace]
      else
        Map.get(context[:additional_workspaces] || %{}, workspace_slug)
      end

    # Check if user already exists in context
    users = Map.get(context, :users, %{})

    user =
      case Map.get(users, email) do
        nil ->
          # Only create user if not already exists
          user_fixture(%{email: email})

        existing_user ->
          existing_user
      end

    # Add membership based on role (only if not already a member)
    role_atom = String.to_existing_atom(role)

    # Check if membership already exists to avoid constraint violation
    existing_member =
      Jarga.Repo.one(
        from(m in Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema,
          where: m.workspace_id == ^workspace.id and m.user_id == ^user.id
        )
      )

    unless existing_member do
      add_workspace_member_fixture(workspace.id, user, role_atom)
    end

    # Store user in context by email for easy lookup
    {:ok, Map.put(context, :users, Map.put(users, email, user))}
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
    cond do
      context[:listed_projects] ->
        # Check project list
        listed_projects = context[:listed_projects]
        actual_names = Enum.map(listed_projects, fn project -> project.name end)

        refute item_name in actual_names,
               "Expected NOT to see '#{item_name}' in project list but it was found"

        {:ok, context}

      context[:last_html] ->
        # Check HTML (document listing)
        html = context[:last_html]
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()
        refute html =~ title_escaped
        {:ok, context}

      context[:session] ->
        # Check HTML from Wallaby session
        html = Wallaby.Browser.page_source(context[:session])
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()

        refute html =~ title_escaped,
               "Expected NOT to see '#{item_name}' in page source but it was found"

        {:ok, context}

      true ->
        flunk("Cannot determine context for 'I should not see' step")
    end
  end

  step "I should see {string}", %{args: [item_name]} = context do
    cond do
      context[:listed_projects] ->
        # Check project list
        listed_projects = context[:listed_projects]
        actual_names = Enum.map(listed_projects, fn project -> project.name end)

        assert item_name in actual_names,
               "Expected to see '#{item_name}' in project list but it was not found"

        {:ok, context}

      context[:last_html] ->
        # Check HTML (document listing)
        html = context[:last_html]
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()
        assert html =~ title_escaped
        {:ok, context}

      context[:session] ->
        # Check HTML from Wallaby session
        html = Wallaby.Browser.page_source(context[:session])
        title_escaped = Phoenix.HTML.html_escape(item_name) |> Phoenix.HTML.safe_to_string()

        assert html =~ title_escaped,
               "Expected to see '#{item_name}' in page source but it was not found"

        {:ok, context}

      true ->
        flunk("Cannot determine context for 'I should see' step")
    end
  end
end
