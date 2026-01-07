defmodule Projects.Api.VerifySteps do
  @moduledoc """
  Verification step definitions for Project API Access feature tests.

  These steps assert expected outcomes of API operations.
  Note: Some steps like "the response status should be {int}" and
  "the response should include error {string}" are already defined
  in Workspaces.Api.VerifySteps and are reused here.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  alias Jarga.Projects

  # ============================================================================
  # PROJECT RESPONSE VERIFICATION
  # ============================================================================

  step "the response should include project {string}", %{args: [project_name]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil. Response: #{inspect(body)}"

    assert data["name"] == project_name,
           "Expected project name '#{project_name}', but got '#{data["name"]}'"

    {:ok, context}
  end

  step "the response should include description {string}",
       %{args: [expected_description]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    assert data["description"] == expected_description,
           "Expected description '#{expected_description}', but got '#{data["description"]}'"

    {:ok, context}
  end

  step "the project should exist in workspace {string}",
       %{args: [workspace_slug]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]
    project_name = data["name"]

    # Verify by checking the database directly
    workspace = get_workspace_by_slug(context, workspace_slug)
    user = context[:current_user]

    projects = Projects.list_projects_for_workspace(user, workspace.id)
    project = Enum.find(projects, fn p -> p.name == project_name end)

    assert project != nil,
           "Expected project '#{project_name}' to exist in workspace '#{workspace_slug}'"

    {:ok, context}
  end

  step "the project {string} should exist in workspace {string}",
       %{args: [project_name, workspace_slug]} = context do
    # Verify by checking the database directly
    workspace = get_workspace_by_slug(context, workspace_slug)
    user = context[:current_user]

    projects = Projects.list_projects_for_workspace(user, workspace.id)
    project = Enum.find(projects, fn p -> p.name == project_name end)

    assert project != nil,
           "Expected project '#{project_name}' to exist in workspace '#{workspace_slug}'"

    {:ok, context}
  end

  step "the project {string} should not exist", %{args: [project_name]} = context do
    # Check that the project was NOT created in any workspace
    workspaces =
      Map.values(context[:workspaces] || %{}) ++
        Map.values(context[:additional_workspaces] || %{})

    user = context[:current_user]

    found =
      Enum.any?(workspaces, fn workspace ->
        projects = Projects.list_projects_for_workspace(user, workspace.id)
        Enum.any?(projects, fn p -> p.name == project_name end)
      end)

    refute found, "Expected project '#{project_name}' to NOT exist, but it was found"

    {:ok, context}
  end

  # ============================================================================
  # VALIDATION ERROR VERIFICATION
  # ============================================================================

  step "the response should include validation error for {string}",
       %{args: [field_name]} = context do
    body = Jason.decode!(context[:response_body])
    errors = body["errors"] || %{}

    assert Map.has_key?(errors, field_name),
           "Expected validation error for '#{field_name}', but got errors: #{inspect(errors)}"

    {:ok, context}
  end

  # Helper to get workspace by slug from context
  defp get_workspace_by_slug(context, slug) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug) ||
      if(context[:workspace] && context[:workspace].slug == slug, do: context[:workspace])
  end
end
