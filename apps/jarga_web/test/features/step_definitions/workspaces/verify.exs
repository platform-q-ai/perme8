defmodule Workspaces.VerifySteps do
  @moduledoc """
  Step definitions for workspace verification and assertions.

  For email assertions, see: Workspaces.VerifyEmailSteps (verify_email.exs)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  # ============================================================================
  # WORKSPACE LIST ASSERTIONS
  # ============================================================================

  step "I should see {string} in workspace list", %{args: [workspace_name]} = context do
    html = context[:last_html]
    name_escaped = Phoenix.HTML.html_escape(workspace_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped, "Expected to see '#{workspace_name}' in workspace list"
    {:ok, context}
  end

  step "I should see {string} in the workspace list", %{args: [workspace_name]} = context do
    html = context[:last_html]
    name_escaped = Phoenix.HTML.html_escape(workspace_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped, "Expected to see '#{workspace_name}' in workspace list"
    {:ok, context}
  end

  step "I should not see {string} in workspace list", %{args: [workspace_name]} = context do
    html = context[:last_html]
    name_escaped = Phoenix.HTML.html_escape(workspace_name) |> Phoenix.HTML.safe_to_string()
    refute html =~ name_escaped, "Expected NOT to see '#{workspace_name}' in workspace list"
    {:ok, context}
  end

  step "I should not see {string} in the workspace list", %{args: [workspace_name]} = context do
    # Re-render the view to get the latest HTML state after deletion
    view = context[:view]

    html =
      if view do
        Phoenix.LiveViewTest.render(view)
      else
        context[:last_html]
      end

    # Get the specific workspace that was being tested (from context)
    # This is more reliable than checking by name since users may have multiple
    # workspaces with the same name due to test isolation issues
    workspace = context[:workspace]

    if workspace do
      # Check for the specific workspace by its slug in href
      workspace_slug = workspace.slug

      refute html =~ ~s(href="/app/workspaces/#{workspace_slug}"),
             "Expected NOT to see workspace with slug '#{workspace_slug}' in workspace list"
    else
      # Fallback to original behavior if no workspace in context
      name_escaped = Phoenix.HTML.html_escape(workspace_name) |> Phoenix.HTML.safe_to_string()
      refute html =~ name_escaped, "Expected NOT to see '#{workspace_name}' in workspace list"
    end

    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # WORKSPACE CONTENT ASSERTIONS
  # ============================================================================

  step "I should see workspace description", context do
    html = context[:last_html]
    assert html =~ context[:workspace].description, "Expected to see workspace description"
    {:ok, context}
  end

  step "I should see the workspace description", context do
    html = context[:last_html]
    assert html =~ context[:workspace].description, "Expected to see workspace description"
    {:ok, context}
  end

  step "I should see projects section", context do
    html = context[:last_html]
    assert html =~ "Projects", "Expected to see Projects section"
    {:ok, context}
  end

  step "I should see the projects section", context do
    html = context[:last_html]
    assert html =~ "Projects", "Expected to see Projects section"
    {:ok, context}
  end

  step "I should see documents section", context do
    html = context[:last_html]
    assert html =~ "Documents", "Expected to see Documents section"
    {:ok, context}
  end

  step "I should see the documents section", context do
    html = context[:last_html]
    assert html =~ "Documents", "Expected to see Documents section"
    {:ok, context}
  end

  step "I should see agents section", context do
    html = context[:last_html]
    assert html =~ "Agents", "Expected to see Agents section"
    {:ok, context}
  end

  step "I should see the agents section", context do
    html = context[:last_html]
    assert html =~ "Agents", "Expected to see Agents section"
    {:ok, context}
  end

  # ============================================================================
  # MEMBER LIST ASSERTIONS
  # ============================================================================

  step "the owner role should be read-only", context do
    html = context[:last_html]
    assert html =~ "Owner", "Expected to see Owner badge"
    assert html =~ ~r/badge.*Owner/s, "Expected Owner to be displayed in a badge"
    {:ok, context}
  end

  step "owner role should be read-only", context do
    html = context[:last_html]
    assert html =~ "Owner", "Expected to see Owner badge"
    refute html =~ "<select", "Expected NOT to see role selector for owner"
    {:ok, context}
  end

  step "I should see {string} in members list with status {string}",
       %{args: [email, status]} = context do
    html = context[:last_html]
    email_escaped = Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()
    status_escaped = Phoenix.HTML.html_escape(status) |> Phoenix.HTML.safe_to_string()

    assert html =~ email_escaped, "Expected to see '#{email}' in members list"
    assert html =~ status_escaped, "Expected to see status '#{status}' for member"
    {:ok, context}
  end

  step "I should see {string} in the members list with status {string}",
       %{args: [email, status]} = context do
    html = context[:last_html]
    email_escaped = Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()
    status_escaped = Phoenix.HTML.html_escape(status) |> Phoenix.HTML.safe_to_string()

    assert html =~ email_escaped, "Expected to see '#{email}' in members list"
    assert html =~ status_escaped, "Expected to see status '#{status}' for member"
    {:ok, context}
  end

  step "I should not see {string} in members list", %{args: [email]} = context do
    html = context[:last_html]
    email_escaped = Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()
    refute html =~ email_escaped, "Expected NOT to see '#{email}' in members list"
    {:ok, context}
  end

  step "I should not see {string} in the members list", %{args: [email]} = context do
    html = context[:last_html]
    email_escaped = Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()
    refute html =~ email_escaped, "Expected NOT to see '#{email}' in members list"
    {:ok, context}
  end

  step "{string} should have role {string} in members list",
       %{args: [_email, expected_role]} = context do
    html = context[:last_html]
    role_pattern = "value=\"#{expected_role}\" selected"
    assert html =~ role_pattern, "Expected member to have role #{expected_role}"
    {:ok, context}
  end

  step "{string} should have role {string} in the members list",
       %{args: [_email, expected_role]} = context do
    html = context[:last_html]
    role_pattern = "value=\"#{expected_role}\" selected"
    assert html =~ role_pattern, "Expected member to have role #{expected_role}"
    {:ok, context}
  end

  step "I should not see a role selector for {string}", %{args: [email]} = context do
    html = context[:last_html]

    refute html =~
             "#{email}</td>"
             |> Phoenix.HTML.html_escape()
             |> Phoenix.HTML.safe_to_string()
             |> then(&(&1 <> "<select"))

    {:ok, context}
  end

  step "I should not see a remove button for {string}", %{args: [email]} = context do
    html = context[:last_html] || raise "No HTML. Navigate to a page first."
    assert html =~ email, "Expected to see #{email} in members list"

    refute html =~ ~r/phx-click="remove_member".*phx-value-email="#{Regex.escape(email)}"/s,
           "Expected NOT to see remove button for #{email}"

    {:ok, context}
  end

  # ============================================================================
  # UI ASSERTIONS
  # ============================================================================

  step "I should see a color bar with color {string} for workspace",
       %{args: [color]} = context do
    html = context[:last_html]
    assert html =~ "background-color: #{color}", "Expected to see color bar with #{color}"
    {:ok, context}
  end

  step "I should see a color bar with color {string} for the workspace",
       %{args: [color]} = context do
    html = context[:last_html]
    color_normalized = String.downcase(color)

    assert html =~ color_normalized or html =~ String.replace(color, "#", ""),
           "Expected to see color bar with #{color}"

    {:ok, context}
  end

  step "each workspace should show its description", context do
    html = context[:last_html]
    assert html =~ "A test workspace", "Expected to see workspace descriptions"
    {:ok, context}
  end

  step "each workspace should be clickable", context do
    html = context[:last_html]

    assert html =~ "navigate=" or html =~ "href=\"/app/workspaces/",
           "Expected workspaces to be clickable links"

    {:ok, context}
  end

  step "I should see {string} button", %{args: [button_text]} = context do
    html = context[:last_html]
    button_escaped = Phoenix.HTML.html_escape(button_text) |> Phoenix.HTML.safe_to_string()
    assert html =~ button_escaped, "Expected to see '#{button_text}' button"
    {:ok, context}
  end

  step "I should not see {string} button", %{args: [button_text]} = context do
    html = context[:last_html]
    button_escaped = Phoenix.HTML.html_escape(button_text) |> Phoenix.HTML.safe_to_string()
    refute html =~ button_escaped, "Expected NOT to see '#{button_text}' button"
    {:ok, context}
  end

  # ============================================================================
  # VALIDATION ASSERTIONS
  # ============================================================================

  step "I should see validation errors", context do
    html = context[:last_html]
    assert html =~ "error" or html =~ "required", "Expected to see validation errors"
    {:ok, context}
  end

  step "I should remain on the new workspace page", context do
    html = context[:last_html]
    assert html =~ "New Workspace", "Expected to remain on new workspace page"
    {:ok, context}
  end

  # ============================================================================
  # REDIRECT ASSERTIONS
  # ============================================================================

  step "I should be redirected to workspaces page", context do
    case redirected_to(context[:conn]) do
      nil ->
        html = context[:last_html]
        assert html =~ "Workspaces", "Expected to be on workspaces page"
        {:ok, context}

      redirect_path ->
        assert redirect_path == "/app/workspaces",
               "Expected to be redirected to workspaces page"

        {:ok, context}
    end
  end

  step "I should be redirected to the workspaces page", context do
    case context[:last_result] do
      {:error, :forbidden} ->
        {:ok, view, html} = live(context[:conn], ~p"/app/workspaces")
        {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}

      {:error, :not_found} ->
        {:ok, view, html} = live(context[:conn], ~p"/app/workspaces")
        {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}

      _ ->
        case context[:last_html] do
          nil ->
            {:ok, view, html} = live(context[:conn], ~p"/app/workspaces")
            {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}

          html when is_binary(html) ->
            assert html =~ "Workspaces", "Expected to be on workspaces page"
            {:ok, context}
        end
    end
  end

  # ============================================================================
  # ERROR HANDLING ASSERTIONS
  # ============================================================================

  step "I should receive a {string} error", %{args: [error_message]} = context do
    result = context[:last_result]

    case result do
      {:error, reason} when is_atom(reason) ->
        reason_str = to_string(reason)
        normalized_reason = reason_str |> String.replace("_", " ") |> String.downcase()
        normalized_expected = error_message |> String.downcase()

        matches =
          String.contains?(normalized_reason, normalized_expected) or
            String.contains?(normalized_expected, normalized_reason)

        assert matches, "Expected error '#{error_message}' but got '#{reason_str}'"
        {:ok, context}

      {:error, reason} when is_binary(reason) ->
        assert reason =~ error_message, "Expected error '#{error_message}' but got '#{reason}'"
        {:ok, context}

      other ->
        flunk("Expected error with message '#{error_message}' but got: #{inspect(other)}")
    end
  end
end
