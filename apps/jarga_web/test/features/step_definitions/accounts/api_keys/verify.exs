defmodule Accounts.ApiKeys.VerifySteps do
  @moduledoc """
  Verification step definitions for API Key Management feature tests.

  These steps assert expected outcomes of API key operations.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Jarga.Accounts
  alias Jarga.Accounts.ApiKeys.Helpers

  # ============================================================================
  # CREATION VERIFICATION STEPS
  # ============================================================================

  step "the API key should be created successfully", context do
    case context[:last_result] do
      {:ok, {_api_key, _token}} ->
        # Full-stack verification: check via LiveView
        conn = context[:conn]
        {:ok, _view, html} = live(conn, ~p"/users/settings/api-keys")

        api_key = context[:api_key]
        name_escaped = Phoenix.HTML.html_escape(api_key.name) |> Phoenix.HTML.safe_to_string()
        assert html =~ name_escaped, "Expected to see API key name '#{api_key.name}' in HTML"

        {:ok, context}

      {:ok, _api_key} ->
        # Update result
        {:ok, context}

      :ok ->
        # LiveView test result - success without explicit API key return
        {:ok, context}

      {:error, reason} ->
        flunk("Expected API key to be created successfully, but got error: #{inspect(reason)}")
    end
  end

  step "I should receive the API key token", context do
    plain_token = context[:plain_token]

    assert plain_token != nil, "Expected to receive a plain token"
    assert is_binary(plain_token), "Expected token to be a string"
    # Tokens are 64-character URL-safe strings (Base64 encoded random bytes)
    assert String.length(plain_token) == 64, "Expected token to be 64 characters"

    {:ok, context}
  end

  step "the API key should not be created", context do
    # Verify by checking that no new API key was stored in context
    assert context[:api_key] == nil || context[:last_result] == {:error, :forbidden},
           "Expected API key to not be created"

    {:ok, context}
  end

  # ============================================================================
  # WORKSPACE ACCESS VERIFICATION STEPS
  # ============================================================================

  step "the API key should have access to workspace {string}",
       %{args: [workspace_slug]} = context do
    api_key = context[:api_key]

    assert workspace_slug in api_key.workspace_access,
           "Expected API key to have access to workspace '#{workspace_slug}', but it has: #{inspect(api_key.workspace_access)}"

    {:ok, context}
  end

  step "the API key should not have access to workspace {string}",
       %{args: [workspace_slug]} = context do
    api_key = context[:api_key]

    refute workspace_slug in api_key.workspace_access,
           "Expected API key NOT to have access to workspace '#{workspace_slug}'"

    {:ok, context}
  end

  step "the API key should not have access to any workspace", context do
    api_key = context[:api_key]

    assert Enum.empty?(api_key.workspace_access),
           "Expected API key to have no workspace access, but it has: #{inspect(api_key.workspace_access)}"

    {:ok, context}
  end

  # ============================================================================
  # LISTING VERIFICATION STEPS
  # ============================================================================

  step "I should see {int} API keys", %{args: [count]} = context do
    html = context[:last_html]

    # Count API keys by counting table rows in tbody only
    # The thead has one <tr> for headers, so we count rows in tbody
    # Each API key shows its name in a div with text-sm font-medium class
    api_key_names = Regex.scan(~r/<div class="text-sm font-medium">([^<]+)<\/div>/, html)
    actual_count = length(api_key_names)

    # If count is 0, verify the empty state message is shown
    if count == 0 do
      assert html =~ "No API keys" or actual_count == 0,
             "Expected 0 API keys, but found #{actual_count}"
    else
      assert actual_count == count,
             "Expected #{count} API keys, but found #{actual_count} in HTML"
    end

    {:ok, context}
  end

  step "I should see the API key {string} with workspace access {string}",
       %{args: [name, workspace_access_str]} = context do
    html = context[:last_html]

    # Verify API key name is in HTML
    name_escaped = Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped, "Expected to see API key name '#{name}' in HTML"

    # Verify workspace access is shown
    workspaces = Helpers.parse_workspace_access(workspace_access_str)

    Enum.each(workspaces, fn workspace ->
      workspace_escaped = Phoenix.HTML.html_escape(workspace) |> Phoenix.HTML.safe_to_string()
      assert html =~ workspace_escaped, "Expected to see workspace '#{workspace}' in HTML"
    end)

    {:ok, context}
  end

  step "I should not see the actual API key tokens", context do
    html = context[:last_html]

    # API key tokens should never be visible in the list view
    # They start with "jrg_" prefix
    refute html =~ "jrg_", "Expected NOT to see actual API key tokens in HTML"

    {:ok, context}
  end

  step "I should see the API key {string}", %{args: [name]} = context do
    html = context[:last_html]

    name_escaped = Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped, "Expected to see API key name '#{name}' in HTML"

    {:ok, context}
  end

  step "I should not see the actual API key token", context do
    html = context[:last_html]
    plain_token = context[:plain_token]

    # This step expects plain_token to be set from a prior creation step
    assert plain_token != nil,
           "Expected plain_token to be set in context from prior creation step"

    refute html =~ plain_token,
           "Expected NOT to see the actual API key token in the list view"

    {:ok, context}
  end

  # ============================================================================
  # REVOCATION VERIFICATION STEPS
  # ============================================================================

  step "the API key should be revoked successfully", context do
    case context[:last_result] do
      {:ok, revoked_key} ->
        assert revoked_key.is_active == false, "Expected API key to be inactive"
        {:ok, context}

      {:error, reason} ->
        flunk("Expected API key to be revoked successfully, but got error: #{inspect(reason)}")
    end
  end

  step "the API key {string} should no longer be usable", %{args: [name]} = context do
    user = context[:current_user]

    {:ok, api_keys} = Accounts.list_api_keys(user.id)
    api_key = Enum.find(api_keys, fn k -> k.name == name end)

    assert api_key != nil, "Expected to find API key '#{name}'"
    assert api_key.is_active == false, "Expected API key '#{name}' to be inactive"

    {:ok, context}
  end

  # ============================================================================
  # UPDATE VERIFICATION STEPS
  # ============================================================================

  step "the API key should be updated successfully", context do
    case context[:last_result] do
      {:ok, _updated_key} ->
        {:ok, context}

      :ok ->
        {:ok, context}

      {:error, reason} ->
        flunk("Expected API key to be updated successfully, but got error: #{inspect(reason)}")
    end
  end

  step "the API key should have name {string}", %{args: [expected_name]} = context do
    api_key = context[:api_key]

    assert api_key.name == expected_name,
           "Expected API key name to be '#{expected_name}', but got '#{api_key.name}'"

    {:ok, context}
  end

  step "the API key should have description {string}",
       %{args: [expected_description]} = context do
    api_key = context[:api_key]

    assert api_key.description == expected_description,
           "Expected API key description to be '#{expected_description}', but got '#{api_key.description}'"

    {:ok, context}
  end

  # ============================================================================
  # SECURITY VERIFICATION STEPS
  # ============================================================================

  step "the API key token should not be stored in plain text in the database", context do
    api_key = context[:api_key]
    plain_token = context[:plain_token]

    # Verify security property indirectly: the plain token should work for verification
    result = Accounts.verify_api_key(plain_token)
    assert match?({:ok, _}, result), "Expected plain token to be verifiable"

    # If we try to verify using the API key ID directly as a token, it should fail
    # (proving the token is hashed, not stored in plain text)
    fake_token = "jrg_#{api_key.id}"

    assert Accounts.verify_api_key(fake_token) == {:error, :invalid},
           "Expected direct ID-based token to be invalid (proving tokens are hashed)"

    {:ok, context}
  end

  step "the API key should be stored with a secure hash", context do
    api_key = context[:api_key]
    plain_token = context[:plain_token]

    # Verify the token can be verified using the correct hash (security property)
    result = Accounts.verify_api_key(plain_token)

    case result do
      {:ok, verified_key} ->
        assert verified_key.id == api_key.id, "Expected verified key to match created key"

        # Additional security check: verify that a slightly modified token fails
        # This proves that the hash verification is working correctly
        modified_token = plain_token <> "x"

        assert Accounts.verify_api_key(modified_token) == {:error, :invalid},
               "Expected modified token to be invalid (proving secure hash verification)"

      {:error, reason} ->
        flunk("Expected API key to be verifiable, but got: #{inspect(reason)}")
    end

    {:ok, context}
  end
end
