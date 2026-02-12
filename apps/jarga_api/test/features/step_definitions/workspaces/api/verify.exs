defmodule Workspaces.Api.VerifySteps do
  @moduledoc """
  Verification step definitions for Workspace API Access feature tests.

  These steps assert expected outcomes of API operations.
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  # ============================================================================
  # RESPONSE STATUS VERIFICATION
  # ============================================================================

  step "the response status should be {int}", %{args: [expected_status]} = context do
    actual_status = context[:response_status]

    assert actual_status == expected_status,
           "Expected response status #{expected_status}, but got #{actual_status}. " <>
             "Response body: #{context[:response_body]}"

    {:ok, context}
  end

  # ============================================================================
  # WORKSPACE LIST VERIFICATION
  # ============================================================================

  step "the response should include {int} workspaces", %{args: [expected_count]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []
    actual_count = length(workspaces)

    assert actual_count == expected_count,
           "Expected #{expected_count} workspaces, but got #{actual_count}. " <>
             "Workspaces: #{inspect(workspaces)}"

    {:ok, Map.put(context, :response_workspaces, workspaces)}
  end

  step "the response should include {int} workspace", %{args: [expected_count]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []
    actual_count = length(workspaces)

    assert actual_count == expected_count,
           "Expected #{expected_count} workspace(s), but got #{actual_count}. " <>
             "Workspaces: #{inspect(workspaces)}"

    {:ok, Map.put(context, :response_workspaces, workspaces)}
  end

  step "the response should include workspace {string} with slug",
       %{args: [workspace_slug]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces_list = body["data"] || []

    # Translate the expected slug from feature file to actual workspace slug
    context_workspaces = context[:workspaces] || %{}

    expected_actual_slug =
      case Map.get(context_workspaces, workspace_slug) do
        %{slug: actual} -> actual
        nil -> workspace_slug
      end

    workspace = Enum.find(workspaces_list, fn w -> w["slug"] == expected_actual_slug end)

    assert workspace != nil,
           "Expected to find workspace '#{expected_actual_slug}' in response, but it was not found. " <>
             "Available workspaces: #{inspect(Enum.map(workspaces_list, & &1["slug"]))}"

    assert workspace["slug"] == expected_actual_slug,
           "Expected workspace to have slug '#{expected_actual_slug}'"

    {:ok, context}
  end

  step "the response should not include workspace {string}",
       %{args: [workspace_slug]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces_list = body["data"] || []

    # Translate the expected slug from feature file to actual workspace slug
    context_workspaces = context[:workspaces] || %{}

    expected_actual_slug =
      case Map.get(context_workspaces, workspace_slug) do
        %{slug: actual} -> actual
        nil -> workspace_slug
      end

    workspace = Enum.find(workspaces_list, fn w -> w["slug"] == expected_actual_slug end)

    assert workspace == nil,
           "Expected NOT to find workspace '#{expected_actual_slug}' in response, but it was found"

    {:ok, context}
  end

  # ============================================================================
  # WORKSPACE DETAIL VERIFICATION
  # ============================================================================

  step "the response should include workspace {string} details",
       %{args: [workspace_slug]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]

    assert workspace != nil, "Expected workspace data in response, but got nil"

    # Translate the expected slug from feature file to actual workspace slug
    workspaces = context[:workspaces] || %{}

    expected_actual_slug =
      case Map.get(workspaces, workspace_slug) do
        %{slug: actual} -> actual
        nil -> workspace_slug
      end

    assert workspace["slug"] == expected_actual_slug,
           "Expected workspace slug '#{expected_actual_slug}', but got '#{workspace["slug"]}'"

    {:ok, Map.put(context, :response_workspace, workspace)}
  end

  step "the response should include workspace slug {string}",
       %{args: [expected_slug]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data in response"

    # Check for workspace_slug first (project API), then slug (workspace API)
    actual_slug = data["workspace_slug"] || data["slug"]

    # Translate the expected slug from feature file to actual workspace slug
    workspaces = context[:workspaces] || %{}

    expected_actual_slug =
      case Map.get(workspaces, expected_slug) do
        %{slug: actual} -> actual
        nil -> expected_slug
      end

    assert actual_slug == expected_actual_slug,
           "Expected workspace slug '#{expected_actual_slug}', but got '#{actual_slug}'"

    {:ok, context}
  end

  # ============================================================================
  # FIELD VERIFICATION
  # ============================================================================

  step "each workspace in the response should have a {string} field",
       %{args: [field_name]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []

    Enum.each(workspaces, fn workspace ->
      assert Map.has_key?(workspace, field_name),
             "Expected workspace to have '#{field_name}' field, but it was missing. " <>
               "Available fields: #{inspect(Map.keys(workspace))}"
    end)

    {:ok, context}
  end

  step "each workspace in the response should have an {string} field",
       %{args: [field_name]} = context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []

    Enum.each(workspaces, fn workspace ->
      assert Map.has_key?(workspace, field_name),
             "Expected workspace to have '#{field_name}' field, but it was missing. " <>
               "Available fields: #{inspect(Map.keys(workspace))}"
    end)

    {:ok, context}
  end

  step "each document in the response should have a {string} field",
       %{args: [field_name]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    documents = workspace["documents"] || []

    assert documents != [], "Expected documents in response to check field"

    Enum.each(documents, fn document ->
      assert Map.has_key?(document, field_name),
             "Expected document to have '#{field_name}' field, but it was missing. " <>
               "Available fields: #{inspect(Map.keys(document))}"
    end)

    {:ok, context}
  end

  step "each project in the response should have a {string} field",
       %{args: [field_name]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    projects = workspace["projects"] || []

    assert projects != [], "Expected projects in response to check field"

    Enum.each(projects, fn project ->
      assert Map.has_key?(project, field_name),
             "Expected project to have '#{field_name}' field, but it was missing. " <>
               "Available fields: #{inspect(Map.keys(project))}"
    end)

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT VERIFICATION
  # ============================================================================

  step "the response should include {int} documents", %{args: [expected_count]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    documents = workspace["documents"] || []
    actual_count = length(documents)

    assert actual_count == expected_count,
           "Expected #{expected_count} documents, but got #{actual_count}. " <>
             "Documents: #{inspect(documents)}"

    {:ok, Map.put(context, :response_documents, documents)}
  end

  step "the response should include document {string} with slug",
       %{args: [document_title]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    documents = workspace["documents"] || []

    document = Enum.find(documents, fn d -> d["title"] == document_title end)

    assert document != nil,
           "Expected to find document '#{document_title}' in response, but it was not found. " <>
             "Available documents: #{inspect(Enum.map(documents, & &1["title"]))}"

    assert document["slug"] != nil, "Expected document to have a slug"

    {:ok, context}
  end

  step "the response should not include document details", context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []

    Enum.each(workspaces, fn workspace ->
      refute Map.has_key?(workspace, "documents"),
             "Expected workspace list NOT to include document details"
    end)

    {:ok, context}
  end

  # ============================================================================
  # PROJECT VERIFICATION
  # ============================================================================

  step "the response should include {int} projects", %{args: [expected_count]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    projects = workspace["projects"] || []
    actual_count = length(projects)

    assert actual_count == expected_count,
           "Expected #{expected_count} projects, but got #{actual_count}. " <>
             "Projects: #{inspect(projects)}"

    {:ok, Map.put(context, :response_projects, projects)}
  end

  step "the response should include project {string} with slug",
       %{args: [project_name]} = context do
    body = Jason.decode!(context[:response_body])
    workspace = body["data"]
    projects = workspace["projects"] || []

    project = Enum.find(projects, fn p -> p["name"] == project_name end)

    assert project != nil,
           "Expected to find project '#{project_name}' in response, but it was not found. " <>
             "Available projects: #{inspect(Enum.map(projects, & &1["name"]))}"

    assert project["slug"] != nil, "Expected project to have a slug"

    {:ok, context}
  end

  step "the response should not include project details", context do
    body = Jason.decode!(context[:response_body])
    workspaces = body["data"] || []

    Enum.each(workspaces, fn workspace ->
      refute Map.has_key?(workspace, "projects"),
             "Expected workspace list NOT to include project details"
    end)

    {:ok, context}
  end

  # ============================================================================
  # ERROR VERIFICATION
  # ============================================================================

  step "the response should include error {string}", %{args: [expected_error]} = context do
    body = Jason.decode!(context[:response_body])
    actual_error = body["error"]

    assert actual_error == expected_error,
           "Expected error '#{expected_error}', but got '#{actual_error}'"

    {:ok, context}
  end
end
