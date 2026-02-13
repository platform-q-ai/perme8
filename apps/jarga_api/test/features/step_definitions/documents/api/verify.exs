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

    actual_owner = data["owner"]
    user = get_in(context, [:users, expected_owner_email])
    acceptable_values = build_acceptable_owner_values(expected_owner_email, user)

    assert actual_owner in acceptable_values,
           "Expected document to be owned by '#{expected_owner_email}', " <>
             "but got owner '#{actual_owner}'"

    {:ok, context}
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
    expected_project_slug = resolve_project_slug(context, expected_project_name)

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
  # CONTENT HASH VERIFICATION
  # ============================================================================

  step "the response should include a content_hash", context do
    body = Jason.decode!(context[:response_body])
    data = body["data"]

    assert data != nil, "Expected response data, but got nil"

    assert is_binary(data["content_hash"]),
           "Expected content_hash to be a string, got: #{inspect(data["content_hash"])}"

    assert String.length(data["content_hash"]) == 64,
           "Expected content_hash to be 64 chars (SHA-256 hex), got length: #{String.length(data["content_hash"] || "")}"

    {:ok, context}
  end

  step "the response should include a content conflict error", context do
    body = Jason.decode!(context[:response_body])

    assert body["error"] == "content_conflict",
           "Expected error 'content_conflict', got '#{body["error"]}'"

    assert is_binary(body["message"]),
           "Expected conflict message to be a string"

    assert body["data"] != nil, "Expected conflict data to be present"

    assert Map.has_key?(body["data"], "content_hash"),
           "Expected conflict data to include content_hash"

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT EXISTENCE VERIFICATION (DB checks)
  # ============================================================================

  step "the document {string} should not exist", %{args: [document_title]} = context do
    # Check that the document was NOT created in any workspace
    user = context[:current_user]
    workspaces = Map.values(context[:workspaces] || %{})

    found = document_exists_in_workspaces?(user, workspaces, document_title)

    refute found, "Expected document '#{document_title}' to NOT exist, but it was found"

    {:ok, context}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp build_acceptable_owner_values(email, nil), do: [email]
  defp build_acceptable_owner_values(email, user), do: [email, user.id]

  defp resolve_project_slug(context, project_name) do
    case get_in(context, [:projects, project_name]) do
      %{slug: slug} -> slug
      nil -> project_name |> String.downcase() |> String.replace(~r/\s+/, "-")
    end
  end

  defp document_exists_in_workspaces?(nil, _workspaces, _title), do: false

  defp document_exists_in_workspaces?(user, workspaces, title) do
    Enum.any?(workspaces, fn workspace ->
      documents = Documents.list_documents_for_workspace(user, workspace.id)
      Enum.any?(documents, fn d -> d.title == title end)
    end)
  end
end
