defmodule Documents.SetupSteps do
  @moduledoc """
  Step definitions for setting up document test fixtures.

  These steps create documents in various states for testing:
  - Public/private documents
  - Documents owned by different users
  - Documents in workspaces vs projects
  - Pinned documents
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository

  # ============================================================================
  # DOCUMENT FIXTURES
  # ============================================================================

  step "a private document exists with title {string} owned by {string}",
       %{args: [title, owner_email]} = context do
    owner = get_in(context, [:users, owner_email])
    workspace = context[:workspace]

    document =
      document_fixture(owner, workspace, nil, %{
        title: title,
        is_public: false
      })

    {:ok, context |> Map.put(:document, document)}
  end

  step "a public document exists with title {string} owned by {string}",
       %{args: [title, owner_email]} = context do
    owner = get_in(context, [:users, owner_email])
    workspace = context[:workspace]

    document =
      document_fixture(owner, workspace, nil, %{
        title: title,
        is_public: true
      })

    {:ok, context |> Map.put(:document, document)}
  end

  step "a document exists with title {string} owned by {string}",
       %{args: [title, owner_email]} = context do
    owner = get_in(context, [:users, owner_email])
    workspace = context[:workspace]

    document = document_fixture(owner, workspace, nil, %{title: title})

    {:ok, context |> Map.put(:document, document)}
  end

  step "a document exists with title {string} in workspace {string}",
       %{args: [title, _workspace_slug]} = context do
    workspace = context[:workspace]
    # Use current_user if logged in, otherwise workspace_owner
    user =
      context[:current_user] || context[:workspace_owner] ||
        hd(Map.values(context[:users] || %{}))

    document = document_fixture(user, workspace, nil, %{title: title})

    {:ok, context |> Map.put(:document, document)}
  end

  step "a document exists with title {string} in project {string}",
       %{args: [title, project_name]} = context do
    workspace = context[:workspace] || raise "No workspace. Set :workspace in a prior step."

    # Look up the specific project by name
    project =
      get_in(context, [:projects, project_name]) || context[:project] ||
        raise "Project '#{project_name}' not found. Create the project in a prior step."

    # Use current_user if available, otherwise workspace_owner
    user =
      context[:current_user] || context[:workspace_owner] ||
        hd(Map.values(context[:users] || %{}))

    document = document_fixture(user, workspace, project, %{title: title})

    # Verify the document was created with the project association
    _document_schema = DocumentRepository.get_by_id_with_project(document.id)

    assert document.project_id == project.id,
           "Document project_id mismatch: expected #{project.id}, got #{document.project_id}"

    {:ok, context |> Map.put(:document, document)}
  end

  step "a pinned document exists with title {string} owned by {string}",
       %{args: [title, owner_email]} = context do
    owner = get_in(context, [:users, owner_email])
    workspace = context[:workspace]

    document =
      document_fixture(owner, workspace, nil, %{
        title: title,
        is_pinned: true
      })

    {:ok, context |> Map.put(:document, document)}
  end

  # ============================================================================
  # DATA TABLE FIXTURES
  # ============================================================================

  step "the following documents exist in workspace {string}:",
       %{args: [_workspace_slug]} = context do
    workspace = context[:workspace]
    users = context[:users]

    # Access data table with DOT notation
    table_data = context.datatable.maps

    documents =
      Enum.map(table_data, fn row ->
        owner = users[row["owner"]]
        is_public = row["visibility"] == "public"

        document_fixture(owner, workspace, nil, %{
          title: row["title"],
          is_public: is_public
        })
      end)

    # Return context directly for data table steps (no {:ok, })
    Map.put(context, :documents, documents)
  end

  step "the following documents exist:", context do
    workspace = context[:workspace]
    users = context[:users]
    # Find projects by name
    table_data = context.datatable.maps

    documents =
      Enum.map(table_data, fn row ->
        # Look up project by name from :projects map or query
        project =
          get_in(context, [:projects, row["project"]]) ||
            find_project_by_name(workspace, row["project"])

        # Use current_user if logged in, otherwise workspace_owner
        user = context[:current_user] || context[:workspace_owner] || hd(Map.values(users))

        document_fixture(user, workspace, project, %{
          title: row["title"]
        })
      end)

    # Return context directly for data table steps
    Map.put(context, :documents, documents)
  end

  # ============================================================================
  # PROJECT FIXTURES
  # ============================================================================

  step "a project exists with name {string} in workspace {string}",
       %{args: [name, workspace_slug]} = context do
    workspace = resolve_workspace(context, workspace_slug)
    user = resolve_workspace_owner(context, workspace, workspace_slug)
    project = project_fixture(user, workspace, %{name: name})

    projects = Map.get(context, :projects, %{})

    {:ok,
     context |> Map.put(:project, project) |> Map.put(:projects, Map.put(projects, name, project))}
  end

  defp resolve_workspace(context, workspace_slug) do
    get_in(context, [:additional_workspaces, workspace_slug]) || context[:workspace] ||
      raise "No workspace. Set :workspace or add to :additional_workspaces in a prior step."
  end

  defp resolve_workspace_owner(context, workspace, workspace_slug) do
    if main_workspace?(context[:workspace], workspace) do
      get_default_owner(context)
    else
      get_additional_workspace_owner(context, workspace_slug)
    end
  end

  defp main_workspace?(nil, _workspace), do: true
  defp main_workspace?(main_ws, workspace), do: workspace.id == main_ws.id

  defp get_default_owner(context) do
    context[:workspace_owner] || hd(Map.values(context[:users] || %{}))
  end

  defp get_additional_workspace_owner(context, workspace_slug) do
    get_in(context, [:additional_owners, workspace_slug]) ||
      context[:workspace_owner] ||
      hd(Map.values(context[:users] || %{}))
  end

  step "user {string} is owner of workspace {string}",
       %{args: [email, workspace_slug]} = context do
    # For additional workspaces, add the user as owner
    additional_workspace = get_in(context, [:additional_workspaces, workspace_slug])

    case additional_workspace do
      nil ->
        # User already has membership from Background
        {:ok, context}

      workspace ->
        user =
          get_in(context, [:users, email]) ||
            raise "User '#{email}' not found. Create the user in a prior step."

        # Add user as owner of additional workspace
        add_workspace_member_fixture(workspace.id, user, :owner)

        {:ok, context}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  alias Jarga.Projects.Infrastructure.Repositories.ProjectRepository

  defp find_project_by_name(workspace, project_name) do
    ProjectRepository.get_by_name(
      workspace.id,
      project_name
    )
  end
end
