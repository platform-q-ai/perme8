defmodule IdentityWeb.ApiKeysLiveTest do
  use IdentityWeb.ConnCase, async: true

  alias Identity
  alias Identity.Domain.Policies.ApiKeyPermissionPolicy
  import Phoenix.LiveViewTest
  import Identity.AccountsFixtures

  describe "API Keys page" do
    test "renders API keys page with empty state", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings/api-keys")

      assert html =~ "API Keys"
      assert html =~ "Manage your API keys for external integrations"
      assert html =~ "No API keys yet"
      assert html =~ "Create your first API key"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/api-keys")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "shows New API Key button", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings/api-keys")

      assert html =~ "New API Key"
    end
  end

  describe "create API key" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "opens create modal when clicking New API Key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      html = lv |> element("button", "New API Key") |> render_click()

      assert html =~ "Create New API Key"
      assert html =~ "Name"
      assert html =~ "Description"
    end

    test "create modal shows permission presets", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()

      assert has_element?(lv, "[data-testid='api-key-name-input']")
      assert has_element?(lv, "[data-testid='permission-preset-full-access']")
      assert has_element?(lv, "[data-testid='permission-preset-read-only']")
      assert has_element?(lv, "[data-testid='permission-preset-agent-operator']")
      assert has_element?(lv, "[data-testid='permission-preset-custom']")
    end

    test "clicking custom preset shows scope checkboxes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      assert has_element?(lv, "[data-testid='scope-agents-read']")
      assert has_element?(lv, "[data-testid='scope-mcp-knowledge-search']")
      assert has_element?(lv, "[data-testid='scope-mcp-jarga-list-workspaces']")
    end

    test "checking and unchecking scopes in custom mode updates selection", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      assert has_element?(lv, "[data-testid='scope-agents-read'][checked]")

      lv |> element("[data-testid='scope-agents-read']") |> render_click()
      refute has_element?(lv, "[data-testid='scope-agents-read'][checked]")

      lv |> element("[data-testid='scope-agents-read']") |> render_click()
      assert has_element?(lv, "[data-testid='scope-agents-read'][checked]")
    end

    test "clicking read only preset loads read-only scope set", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-read-only']") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      assert has_element?(lv, "[data-testid='scope-agents-read'][checked]")
      refute has_element?(lv, "[data-testid='scope-agents-write'][checked]")
      assert has_element?(lv, "[data-testid='scope-mcp-knowledge-search'][checked]")
    end

    test "clicking full access preset selects wildcard permissions", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-read-only']") |> render_click()
      lv |> element("[data-testid='permission-preset-full-access']") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      assert has_element?(lv, "[data-testid='scope-agents-write'][checked]")
      assert has_element?(lv, "[data-testid='scope-mcp-jarga-list-workspaces'][checked]")
    end

    test "submitting create with full access preset creates key with wildcard permission", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()

      lv
      |> form("#create_form", %{"name" => "Full Access Key", "description" => ""})
      |> render_submit()

      {:ok, keys} = Identity.list_api_keys(user.id)
      created_key = Enum.find(keys, &(&1.name == "Full Access Key"))

      assert created_key.permissions == ["*"]
    end

    test "submitting create with read only preset creates key with read only scopes", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-read-only']") |> render_click()

      lv
      |> form("#create_form", %{"name" => "Read Only Key", "description" => ""})
      |> render_submit()

      {:ok, keys} = Identity.list_api_keys(user.id)
      created_key = Enum.find(keys, &(&1.name == "Read Only Key"))

      assert created_key.permissions ==
               ApiKeyPermissionPolicy.presets()["Read Only"]
    end

    test "submitting create with specific custom scopes creates key with those scopes", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-agent-operator']") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      for testid <- [
            "scope-agents-query",
            "scope-agents-write",
            "scope-mcp-knowledge-search",
            "scope-mcp-jarga-list-workspaces"
          ] do
        lv |> element("[data-testid='#{testid}']") |> render_click()
      end

      lv
      |> form("#create_form", %{"name" => "Custom Key", "description" => ""})
      |> render_submit()

      {:ok, keys} = Identity.list_api_keys(user.id)
      created_key = Enum.find(keys, &(&1.name == "Custom Key"))

      assert Enum.sort(created_key.permissions) ==
               Enum.sort(["agents:read", "mcp:knowledge.search", "mcp:jarga.list_workspaces"])
    end

    test "empty custom permissions shows warning and still saves", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()
      lv |> element("[data-testid='permission-preset-agent-operator']") |> render_click()
      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      for testid <- ["scope-agents-read", "scope-agents-write", "scope-agents-query"] do
        lv |> element("[data-testid='#{testid}']") |> render_click()
      end

      assert render(lv) =~ "Empty permissions will deny all access"

      html =
        lv
        |> form("#create_form", %{"name" => "No Access Key", "description" => ""})
        |> render_submit()

      assert html =~ "Your API Key"

      {:ok, keys} = Identity.list_api_keys(user.id)
      created_key = Enum.find(keys, &(&1.name == "No Access Key"))

      assert created_key.permissions == []
    end

    test "token modal still shows one-time token display", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv |> element("button", "New API Key") |> render_click()

      lv
      |> form("#create_form", %{"name" => "Token Check", "description" => ""})
      |> render_submit()

      assert has_element?(lv, "#api_key_token")
      assert render(lv) =~ "This token is shown only once"
    end

    test "creates API key and shows token modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open create modal
      lv |> element("button", "New API Key") |> render_click()

      # Submit form
      html =
        lv
        |> form("#create_form", %{
          "name" => "Test API Key",
          "description" => "A test key for integration"
        })
        |> render_submit()

      # Should show token modal with the new key
      assert html =~ "Your API Key"
      assert html =~ "This token is shown only once"
      assert html =~ "copied the key"
      assert html =~ "API key created successfully!"
    end

    test "creates API key without description", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open create modal
      lv |> element("button", "New API Key") |> render_click()

      # Submit form with only name
      html =
        lv
        |> form("#create_form", %{
          "name" => "Minimal Key",
          "description" => ""
        })
        |> render_submit()

      assert html =~ "Your API Key"
      assert html =~ "API key created successfully!"
    end

    test "closes create modal on cancel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open create modal
      lv |> element("button", "New API Key") |> render_click()

      # Cancel
      html = lv |> element("button", "Cancel") |> render_click()

      refute html =~ "Create New API Key"
    end

    test "closes token modal after copying key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open create modal and create key
      lv |> element("button", "New API Key") |> render_click()

      lv
      |> form("#create_form", %{
        "name" => "Test Key",
        "description" => ""
      })
      |> render_submit()

      # Close token modal
      html = lv |> element("button", "I've copied the key") |> render_click()

      refute html =~ "Your API Key"
      refute html =~ "This token is shown only once"
    end
  end

  describe "list API keys" do
    setup %{conn: conn} do
      user = user_fixture()

      # Create some API keys
      {:ok, {key1, _token1}} =
        Identity.create_api_key(user.id, %{
          name: "Production Key",
          description: "For production use"
        })

      {:ok, {key2, _token2}} =
        Identity.create_api_key(user.id, %{
          name: "Development Key",
          description: "For development"
        })

      %{conn: log_in_user(conn, user), user: user, key1: key1, key2: key2}
    end

    test "displays all API keys in a table", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings/api-keys")

      assert html =~ "Production Key"
      assert html =~ "For production use"
      assert html =~ "Development Key"
      assert html =~ "For development"
      assert html =~ "Active"
    end

    test "shows filter buttons", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings/api-keys")

      assert html =~ "All (2)"
      assert html =~ "Active (2)"
      assert html =~ "Revoked (0)"
    end

    test "filters by active status", %{conn: conn, user: user, key1: key1} do
      # Revoke one key
      {:ok, _revoked} = Identity.revoke_api_key(user.id, key1.id)

      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Filter to active only
      html = lv |> element("button", "Active (1)") |> render_click()

      assert html =~ "Development Key"
      refute html =~ "Production Key"
    end

    test "filters by inactive status", %{conn: conn, user: user, key1: key1} do
      # Revoke one key
      {:ok, _revoked} = Identity.revoke_api_key(user.id, key1.id)

      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Filter to revoked only
      html = lv |> element("button", "Revoked (1)") |> render_click()

      assert html =~ "Production Key"
      assert html =~ "Revoked"
      refute html =~ "Development Key"
    end

    test "shows all when All filter is clicked", %{conn: conn, user: user, key1: key1} do
      # Revoke one key
      {:ok, _revoked} = Identity.revoke_api_key(user.id, key1.id)

      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Filter to revoked first
      lv |> element("button", "Revoked (1)") |> render_click()

      # Then back to all
      html = lv |> element("button", "All (2)") |> render_click()

      assert html =~ "Production Key"
      assert html =~ "Development Key"
    end
  end

  describe "permission badges" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, {_full_nil, _}} =
        Identity.create_api_key(user.id, %{name: "Nil Permissions", description: ""})

      {:ok, {_full_wildcard, _}} =
        Identity.create_api_key(user.id, %{name: "Wildcard", description: "", permissions: ["*"]})

      {:ok, {_read_only, _}} =
        Identity.create_api_key(user.id, %{
          name: "Read Only",
          description: "",
          permissions: ApiKeyPermissionPolicy.presets()["Read Only"]
        })

      {:ok, {_agent_operator, _}} =
        Identity.create_api_key(user.id, %{
          name: "Agent Operator",
          description: "",
          permissions: ApiKeyPermissionPolicy.presets()["Agent Operator"]
        })

      {:ok, {_custom, _}} =
        Identity.create_api_key(user.id, %{
          name: "Custom",
          description: "",
          permissions: ["agents:read", "mcp:knowledge.search"]
        })

      {:ok, {_none, _}} =
        Identity.create_api_key(user.id, %{name: "No Access", description: "", permissions: []})

      %{conn: log_in_user(conn, user)}
    end

    test "shows permissions column and summary badges", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      assert has_element?(lv, "th", "Permissions")
      assert has_element?(lv, "[data-testid='api-key-permission-badge']", "Full Access")
      assert has_element?(lv, "[data-testid='api-key-permission-badge']", "Read Only")
      assert has_element?(lv, "[data-testid='api-key-permission-badge']", "Agent Operator")
      assert has_element?(lv, "[data-testid='api-key-permission-badge']", "Custom (2 scopes)")
      assert has_element?(lv, "[data-testid='api-key-permission-badge']", "No Access")
    end
  end

  describe "edit API key" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, {api_key, _token}} =
        Identity.create_api_key(user.id, %{
          name: "Original Name",
          description: "Original description"
        })

      %{conn: log_in_user(conn, user), user: user, api_key: api_key}
    end

    test "opens edit modal when clicking edit button", %{conn: conn, api_key: api_key} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      html =
        lv
        |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
        |> render_click()

      assert html =~ "Edit API Key"
      assert html =~ "Original Name"
      assert html =~ "Original description"
    end

    test "edit button includes slugified data-testid", %{conn: conn} do
      user = user_fixture()

      {:ok, {_api_key, _token}} =
        Identity.create_api_key(user.id, %{name: "Key With Spaces", description: ""})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/api-keys")

      assert has_element?(lv, "[data-testid='edit-api-key-key-with-spaces']")
    end

    test "edit modal pre-selects key permissions", %{conn: conn, api_key: api_key, user: user} do
      {:ok, _updated_key} =
        Identity.update_api_key(user.id, api_key.id, %{
          permissions: ["agents:read", "agents:write", "agents:query"]
        })

      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv
      |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
      |> render_click()

      assert has_element?(
               lv,
               "[data-testid='permission-preset-agent-operator'][aria-pressed='true']"
             )
    end

    test "updates API key name and description", %{conn: conn, api_key: api_key} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open edit modal
      lv
      |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
      |> render_click()

      # Submit updated form
      html =
        lv
        |> form("#edit_form", %{
          "api_key_id" => api_key.id,
          "name" => "Updated Name",
          "description" => "Updated description"
        })
        |> render_submit()

      assert html =~ "API key updated successfully!"
      assert html =~ "Updated Name"
      assert html =~ "Updated description"
    end

    test "saving edited permissions updates the key", %{conn: conn, api_key: api_key, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv
      |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
      |> render_click()

      lv |> element("[data-testid='permission-preset-read-only']") |> render_click()

      lv
      |> form("#edit_form", %{
        "api_key_id" => api_key.id,
        "name" => api_key.name,
        "description" => api_key.description
      })
      |> render_submit()

      {:ok, keys} = Identity.list_api_keys(user.id)
      edited_key = Enum.find(keys, &(&1.id == api_key.id))

      assert edited_key.permissions ==
               ApiKeyPermissionPolicy.presets()["Read Only"]
    end

    test "key with nil permissions shows full access selected and all scopes checked", %{
      conn: conn,
      api_key: api_key
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      lv
      |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
      |> render_click()

      assert has_element?(
               lv,
               "[data-testid='permission-preset-full-access'][aria-pressed='true']"
             )

      lv |> element("[data-testid='permission-preset-custom']") |> render_click()

      assert has_element?(lv, "[data-testid='scope-agents-read'][checked]")
      assert has_element?(lv, "[data-testid='scope-mcp-knowledge-search'][checked]")
      assert has_element?(lv, "[data-testid='scope-mcp-jarga-list-workspaces'][checked]")
    end

    test "closes edit modal on cancel", %{conn: conn, api_key: api_key} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Open edit modal
      lv
      |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
      |> render_click()

      # Cancel
      html = lv |> element("button", "Cancel") |> render_click()

      refute html =~ "Edit API Key"
    end
  end

  describe "revoke API key" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, {api_key, _token}} =
        Identity.create_api_key(user.id, %{
          name: "Key to Revoke",
          description: "This will be revoked"
        })

      %{conn: log_in_user(conn, user), user: user, api_key: api_key}
    end

    test "revokes API key", %{conn: conn, api_key: api_key} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      html =
        lv
        |> element("button[phx-click='revoke_key'][phx-value-id='#{api_key.id}']")
        |> render_click()

      assert html =~ "API key revoked successfully!"
      assert html =~ "Revoked"
    end

    test "revoked key cannot be edited", %{conn: conn, api_key: api_key, user: user} do
      # Revoke the key first
      {:ok, _revoked} = Identity.revoke_api_key(user.id, api_key.id)

      {:ok, _lv, html} = live(conn, ~p"/users/settings/api-keys")

      # Revoked keys should not have edit/revoke buttons
      refute html =~ "button[phx-click='edit_key'][phx-value-id='#{api_key.id}']"
      refute html =~ "button[phx-click='revoke_key'][phx-value-id='#{api_key.id}']"
    end
  end

  describe "empty states" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, {api_key, _token}} =
        Identity.create_api_key(user.id, %{name: "Active Key", description: ""})

      %{conn: log_in_user(conn, user), user: user, api_key: api_key}
    end

    test "shows message when no active keys after filtering", %{
      conn: conn,
      user: user,
      api_key: api_key
    } do
      # Revoke the only key
      {:ok, _revoked} = Identity.revoke_api_key(user.id, api_key.id)

      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Filter to active only
      html = lv |> element("button", "Active (0)") |> render_click()

      assert html =~ "No active API keys"
    end

    test "shows message when no revoked keys", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings/api-keys")

      # Filter to revoked only
      html = lv |> element("button", "Revoked (0)") |> render_click()

      assert html =~ "No revoked API keys"
    end
  end
end
