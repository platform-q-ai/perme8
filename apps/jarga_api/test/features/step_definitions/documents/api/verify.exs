defmodule Documents.Api.VerifySteps do
  @moduledoc """
  Verification step definitions for Document API Access feature tests.

  These steps assert expected outcomes of document API operations.

  Note: The following steps are already defined in existing verify modules
  and must NOT be redefined here:
  - `the response status should be {int}` (Workspaces.Api.VerifySteps)
  - `the response should include error {string}` (Workspaces.Api.VerifySteps)
  - `the response should include validation error for {string}` (Projects.Api.VerifySteps)
  - `the response should include workspace slug {string}` (Workspaces.Api.VerifySteps)
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  alias Jarga.Documents

  # ============================================================================
  # DOCUMENT RESPONSE VERIFICATION
  # ============================================================================

  step "the response should include document {string}", %{args: [document_title]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil. Response: #{inspect(body)}"

    assert data["title"] == document_title,
           "Expected document title '#{document_title}', but got '#{data["title"]}'"

    {:ok, context}
  end

  step "the response should include content {string}", %{args: [expected_content]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    assert data["content"] == expected_content,
           "Expected content '#{expected_content}', but got '#{data["content"]}'"

    {:ok, context}
  end

  step "the response should include owner {string}", %{args: [expected_owner]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    assert data["owner"] == expected_owner,
           "Expected owner '#{expected_owner}', but got '#{data["owner"]}'"

    {:ok, context}
  end

  step "the response should include project slug {string}",
       %{args: [expected_project_slug]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    assert data["project_slug"] == expected_project_slug,
           "Expected project slug '#{expected_project_slug}', but got '#{data["project_slug"]}'"

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT OWNERSHIP & VISIBILITY VERIFICATION
  # ============================================================================

  step "the document {string} should be owned by {string}",
       %{args: [_document_title, expected_owner_email]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil. Response: #{inspect(body)}"

    # For POST responses, the owner field may be the user_id (UUID) or email
    # depending on the JSON view. For GET responses, it should be the email.
    # The DocumentApiJSON.created/1 sets owner to document.created_by (user_id).
    # We check both cases: if owner matches email directly, or resolve via context.
    actual_owner = data["owner"]

    if actual_owner == expected_owner_email do
      # Direct match (GET responses resolve to email)
      {:ok, context}
    else
      # For POST responses, owner might be user_id. Look up the user from context.
      user = get_in(context, [:users, expected_owner_email])

      if user && actual_owner == user.id do
        # Owner is the user_id, which matches the expected user
        {:ok, context}
      else
        flunk(
          "Expected document to be owned by '#{expected_owner_email}', " <>
            "but got owner '#{actual_owner}'"
        )
      end
    end
  end

  step "the document should exist in workspace {string}",
       %{args: [expected_workspace_slug]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    actual_slug = data["workspace_slug"]

    # Translate feature-file workspace slug to actual slug
    workspaces = context[:workspaces] || %{}

    expected_actual_slug =
      case Map.get(workspaces, expected_workspace_slug) do
        %{slug: actual} -> actual
        nil -> expected_workspace_slug
      end

    assert actual_slug == expected_actual_slug,
           "Expected document to exist in workspace '#{expected_actual_slug}', " <>
             "but got workspace_slug '#{actual_slug}'"

    {:ok, context}
  end

  step "the document should exist in project {string}",
       %{args: [expected_project_name]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    # Look up the project from context to get its slug
    project = get_in(context, [:projects, expected_project_name])

    expected_project_slug =
      if project do
        project.slug
      else
        # Fallback: derive slug from project name
        expected_project_name |> String.downcase() |> String.replace(~r/\s+/, "-")
      end

    assert data["project_slug"] == expected_project_slug,
           "Expected document to exist in project '#{expected_project_slug}', " <>
             "but got project_slug '#{data["project_slug"]}'"

    {:ok, context}
  end

  step "the document {string} should have visibility {string}",
       %{args: [_document_title, expected_visibility]} = context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil. Response: #{inspect(body)}"

    assert data["visibility"] == expected_visibility,
           "Expected visibility '#{expected_visibility}', but got '#{data["visibility"]}'"

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT EXISTENCE VERIFICATION (DB checks)
  # ============================================================================

  step "the document {string} should not exist", %{args: [document_title]} = context do
    # Check that the document was NOT created in any workspace
    workspaces =
      Map.values(context[:workspaces] || %{}) ++
        Map.values(context[:additional_workspaces] || %{})

    # Use workspace owners to query since Documents requires a user for access control
    found =
      Enum.any?(workspaces, fn workspace ->
        # Get an owner/user who can see documents in this workspace
        user =
          get_in(context, [:workspace_owners, workspace.slug]) ||
            context[:current_user]

        if user do
          documents = Documents.list_documents_for_workspace(user, workspace.id)
          Enum.any?(documents, fn d -> d.title == document_title end)
        else
          false
        end
      end)

    refute found, "Expected document '#{document_title}' to NOT exist, but it was found"

    {:ok, context}
  end
end
