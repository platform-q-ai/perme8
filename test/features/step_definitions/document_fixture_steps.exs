defmodule DocumentFixtureSteps do
  @moduledoc """
  Cucumber step definitions for setting up document test fixtures.

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

  alias Jarga.Repo
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

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
    workspace = context[:workspace]
    # Look up the specific project by name
    project = get_in(context, [:projects, project_name]) || context[:project]

    # Use current_user if available, otherwise workspace_owner
    user =
      context[:current_user] || context[:workspace_owner] ||
        hd(Map.values(context[:users] || %{}))

    document = document_fixture(user, workspace, project, %{title: title})

    # Verify the document was created with the project association
    _document_schema =
      DocumentSchema |> Repo.get!(document.id) |> Repo.preload(:project, force: true)

    if document.project_id != project.id do
      raise "DocumentSchema project_id mismatch: expected #{project.id}, got #{document.project_id}"
    end

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
    # Check if this is for an additional workspace or the main workspace
    workspace =
      get_in(context, [:additional_workspaces, workspace_slug]) || context[:workspace]

    # Get the owner for the specific workspace
    user =
      if workspace.id == context[:workspace].id do
        context[:workspace_owner] || hd(Map.values(context[:users] || %{}))
      else
        # For additional workspace, get owner from additional_owners
        get_in(context, [:additional_owners, workspace_slug]) ||
          context[:workspace_owner] ||
          hd(Map.values(context[:users] || %{}))
      end

    project = project_fixture(user, workspace, %{name: name})

    # Store both as :project (last one) and in :projects map (all of them)
    projects = Map.get(context, :projects, %{})

    {:ok,
     context
     |> Map.put(:project, project)
     |> Map.put(:projects, Map.put(projects, name, project))}
  end

  step "user {string} is owner of workspace {string}",
       %{args: [email, workspace_slug]} = context do
    # For additional workspaces, add the user as owner
    if additional_workspace = get_in(context, [:additional_workspaces, workspace_slug]) do
      user = get_in(context, [:users, email])

      # Add user as owner of additional workspace
      add_workspace_member_fixture(additional_workspace.id, user, :owner)

      {:ok, context}
    else
      # User already has membership from Background
      {:ok, context}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp find_project_by_name(workspace, project_name) do
    import Ecto.Query
    alias Jarga.Projects.Infrastructure.Schemas.ProjectSchema

    Repo.all(
      from(p in ProjectSchema,
        where: p.workspace_id == ^workspace.id and p.name == ^project_name
      )
    )
    |> List.first()
  end
end
