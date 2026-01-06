defmodule Workspaces.Api.SetupSteps do
  @moduledoc """
  Setup step definitions for Workspace API Access feature tests.

  These steps create test fixtures (API keys, documents, projects) specific to
  API access scenarios. Shared steps (users, workspaces, authentication) are
  defined in other modules:
  - `Workspaces.SetupSteps` - "the following users exist:"
  - `Accounts.ApiKeys.SetupSteps` - "the following workspaces exist:"
  - `CommonSteps` - "I am logged in as {string}"
  - `AgentAuthorizeSteps` - "{string} is a member of workspace {string}"
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Workspaces.Api.Helpers

  # ============================================================================
  # WORKSPACE MEMBERSHIP STEPS (with role specification)
  # ============================================================================

  step "{string} has {string} role in workspace {string}",
       %{args: [email, role, workspace_slug]} = context do
    user = get_in(context, [:users, email]) || raise "User #{email} not found in users"
    workspace = Helpers.get_workspace_by_slug(context, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context"
    end

    # Use String.to_atom/1 since role atoms may not exist yet at compile time
    role_atom = String.to_atom(role)

    # Check if user is already a member (e.g., as owner)
    try do
      add_workspace_member_fixture(workspace.id, user, role_atom)
    rescue
      # If already a member, we might need to update their role
      # For now, just ignore the error
      Ecto.ConstraintError -> :ok
      Ecto.InvalidChangesetError -> :ok
    end

    {:ok, context}
  end

  # ============================================================================
  # API KEY SETUP STEPS (specific to this API feature)
  # ============================================================================

  step "I have an API key {string} with access to {string}",
       %{args: [key_name, workspace_access_str]} = context do
    user = context[:current_user]
    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    {api_key, plain_token} =
      Helpers.create_api_key_fixture(user.id, %{
        name: key_name,
        workspace_access: workspace_access,
        is_active: true
      })

    api_keys = Map.get(context, :api_keys, %{})
    api_tokens = Map.get(context, :api_tokens, %{})

    {:ok,
     context
     |> Map.put(:api_keys, Map.put(api_keys, key_name, api_key))
     |> Map.put(:api_tokens, Map.put(api_tokens, key_name, plain_token))}
  end

  step "I have an API key {string} with no workspace access", %{args: [key_name]} = context do
    user = context[:current_user]

    {api_key, plain_token} =
      Helpers.create_api_key_fixture(user.id, %{
        name: key_name,
        workspace_access: [],
        is_active: true
      })

    api_keys = Map.get(context, :api_keys, %{})
    api_tokens = Map.get(context, :api_tokens, %{})

    {:ok,
     context
     |> Map.put(:api_keys, Map.put(api_keys, key_name, api_key))
     |> Map.put(:api_tokens, Map.put(api_tokens, key_name, plain_token))}
  end

  step "I have a revoked API key {string} with access to {string}",
       %{args: [key_name, workspace_access_str]} = context do
    user = context[:current_user]
    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    {api_key, plain_token} =
      Helpers.create_api_key_fixture(user.id, %{
        name: key_name,
        workspace_access: workspace_access,
        is_active: false
      })

    api_keys = Map.get(context, :api_keys, %{})
    api_tokens = Map.get(context, :api_tokens, %{})

    {:ok,
     context
     |> Map.put(:api_keys, Map.put(api_keys, key_name, api_key))
     |> Map.put(:api_tokens, Map.put(api_tokens, key_name, plain_token))}
  end

  # ============================================================================
  # WORKSPACE EXISTS STEP (for non-table setup)
  # ============================================================================

  step "workspace {string} exists", %{args: [workspace_slug]} = context do
    # Verify workspace exists in context (already set up in Background)
    workspace = Helpers.get_workspace_by_slug(context, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context. Make sure it was created in Background."
    end

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT SETUP STEPS
  # ============================================================================

  step "workspace {string} has the following documents:", %{args: [workspace_slug]} = context do
    table_data = context.datatable.maps
    users = context[:users] || %{}
    workspace = Helpers.get_workspace_by_slug(context, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context"
    end

    documents =
      Enum.map(table_data, fn row ->
        owner_email = row["Owner"]
        owner = Map.get(users, owner_email) || raise "Owner #{owner_email} not found in users"

        # Default to public for API access tests unless explicitly set
        is_public =
          case row["Visibility"] do
            "private" -> false
            # Default to public for API access
            _ -> true
          end

        document_fixture(owner, workspace, nil, %{
          title: row["Title"],
          content: row["Content"] || "",
          is_public: is_public
        })
      end)

    workspace_documents = Map.get(context, :workspace_documents, %{})

    # Return context directly for data table steps
    Map.put(
      context,
      :workspace_documents,
      Map.put(workspace_documents, workspace_slug, documents)
    )
  end

  # ============================================================================
  # PROJECT SETUP STEPS
  # ============================================================================

  step "workspace {string} has the following projects:", %{args: [workspace_slug]} = context do
    table_data = context.datatable.maps
    workspace = Helpers.get_workspace_by_slug(context, workspace_slug)
    workspace_owner = get_in(context, [:workspace_owners, workspace_slug])

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context"
    end

    # Use workspace owner to create projects
    owner = workspace_owner || context[:current_user]

    projects =
      Enum.map(table_data, fn row ->
        project_fixture(owner, workspace, %{
          name: row["Name"],
          description: row["Description"] || ""
        })
      end)

    workspace_projects = Map.get(context, :workspace_projects, %{})

    # Return context directly for data table steps
    Map.put(context, :workspace_projects, Map.put(workspace_projects, workspace_slug, projects))
  end
end
