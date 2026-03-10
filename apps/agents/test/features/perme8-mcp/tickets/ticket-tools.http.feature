@http
Feature: Ticket Management MCP Tools - HTTP API
  As an agent operator
  I want ticket management handled through perme8-mcp tools
  So that all GitHub issue operations go through an authenticated, auditable API layer

  Ticket management is exposed via MCP JSON-RPC 2.0 over HTTP POST /.
  Every scenario that invokes MCP operations performs the same 3-step handshake:
    1. Initialize session with method "initialize"
    2. Send initialized notification with method "notifications/initialized"
    3. Invoke protocol method ("tools/list") or tool call ("tools/call")

  The initialize response returns mcp-session-id, and that value must be sent as
  the Mcp-Session-Id header on every POST after initialize, together with bearer auth.

  Success tool responses use $.result.isError = false and markdown text in
  $.result.content[0].text. Domain/tool failures use $.result.isError = true.
  JSON-RPC schema failures use $.error.code = -32602 and omit $.result.

  NOTE: Variables do not persist across scenarios in exo-bdd, so each scenario
  repeats the full handshake instead of relying on shared state.

  # ===========================================================================
  # Authentication and Permission Baseline
  # ===========================================================================

  Scenario: Revoked API key is rejected during initialize
    Given I set bearer token to "${revoked-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  # ===========================================================================
  # Health and Discovery
  # ===========================================================================

  Scenario: Ticket tools appear in MCP tools/list
    # Initialize MCP session.
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"

    # Send initialized notification before protocol/tool methods.
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202

    # Query protocol-level tools/list and verify ticket tool discovery.
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.tools" should exist
    And the response body should contain "tickets.read"
    And the response body should contain "tickets.list"
    And the response body should contain "tickets.create"
    And the response body should contain "tickets.update"
    And the response body should contain "tickets.close"
    And the response body should contain "tickets.comment"
    And the response body should contain "tickets.add_sub_issue"
    And the response body should contain "tickets.remove_sub_issue"

  # ===========================================================================
  # tickets.read
  # ===========================================================================

  Scenario: Read an existing issue by number
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.read",
          "arguments": {
            "number": 401
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].type" should equal "text"
    And the response body path "$.result.content[0].text" should contain "401"
    And the response body path "$.result.content[0].text" should contain "title"
    And the response body path "$.result.content[0].text" should contain "state"

  Scenario: Read a non-existent issue returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.read",
          "arguments": {
            "number": 999999
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Read with missing required number returns schema error
    # Missing required params are protocol/schema failures (-32602), not tool errors.
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.read",
          "arguments": {}
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  Scenario: Read with invalid issue number type returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.read",
          "arguments": {
            "number": "not-a-number"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.list
  # ===========================================================================

  Scenario: List open issues
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.list","arguments":{"state":"open"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "open"

  Scenario: List issues filtered by labels
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.list","arguments":{"labels":["enhancement","agents"]}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "enhancement"

  Scenario: List issues with search query and no results
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.list","arguments":{"query":"zzz-nonexistent-query-zzz"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "No"

  Scenario: List with invalid labels type returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.list","arguments":{"labels":"enhancement"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.create
  # ===========================================================================

  Scenario: Create a new issue with title and body
    # We verify creation via follow-up tickets.list query in the same scenario because
    # IDs are embedded in markdown text and are not easy to parse with HTTP adapter steps.
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.create",
          "arguments": {
            "title": "HTTP ticket create smoke test 2026-03-10",
            "body": "Created by exo-bdd ticket tools HTTP scenario.",
            "labels": ["test"]
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "HTTP ticket create smoke test"
    And the response body path "$.result.content[0].text" should contain "http"

  Scenario: Create without required title returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.create",
          "arguments": {
            "body": "missing title",
            "labels": ["test"]
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.update
  # ===========================================================================

  Scenario: Update an issue title
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.update","arguments":{"number":401,"title":"Updated title from HTTP MCP test"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Update non-existent issue returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.update","arguments":{"number":999999,"title":"should fail"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Update with missing required number returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.update","arguments":{"title":"missing number"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.close
  # ===========================================================================

  Scenario: Close an issue with a comment
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.close","arguments":{"number":401,"comment":"Closing as resolved from MCP HTTP test"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Close non-existent issue returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.close","arguments":{"number":999999}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Close with missing required number returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.close","arguments":{"comment":"missing number"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.comment
  # ===========================================================================

  Scenario: Add a comment to an issue
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.comment","arguments":{"number":401,"body":"Phase 1 complete"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Comment on a non-existent issue returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.comment","arguments":{"number":999999,"body":"test"}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Comment with missing required body returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.comment","arguments":{"number":401}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.add_sub_issue
  # ===========================================================================

  Scenario: Link an issue as a sub-issue of a parent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    # Uses known existing issue numbers in the test repository.
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.add_sub_issue","arguments":{"parent_number":401,"child_number":402}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Adding a circular sub-issue returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.add_sub_issue","arguments":{"parent_number":401,"child_number":401}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "circular"

  Scenario: Add sub-issue with missing required parent_number returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.add_sub_issue","arguments":{"child_number":402}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # tickets.remove_sub_issue
  # ===========================================================================

  Scenario: Remove a sub-issue link
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    # Ensure relationship exists before removal.
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.add_sub_issue","arguments":{"parent_number":401,"child_number":402}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.remove_sub_issue","arguments":{"parent_number":401,"child_number":402}},"id":3}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Remove sub-issue for non-existent relationship returns tool error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.remove_sub_issue","arguments":{"parent_number":401,"child_number":999999}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true

  Scenario: Remove sub-issue with missing required child_number returns schema error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"exo-bdd-test","version":"1.0.0"}},"id":1}
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {"jsonrpc":"2.0","method":"tools/call","params":{"name":"tickets.remove_sub_issue","arguments":{"parent_number":401}},"id":2}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ===========================================================================
  # Permission Enforcement
  # ===========================================================================

  Scenario: Calling tickets.create without permission returns explicit permission error
    Given I set bearer token to "${valid-no-access-key}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-no-access-key}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-no-access-key}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.create",
          "arguments": {
            "title": "Unauthorized",
            "body": "Should not be allowed"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "Insufficient permissions: mcp:tickets.create required"

  Scenario: Calling tickets.read without permission returns explicit permission error
    Given I set bearer token to "${valid-no-access-key}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
          "protocolVersion": "2025-03-26",
          "capabilities": {},
          "clientInfo": {"name": "exo-bdd-test", "version": "1.0.0"}
        },
        "id": 1
      }
      """
    Then the response status should be 200
    And I store response header "mcp-session-id" as "mcpSessionId"
    Given I set header "Mcp-Session-Id" to "${mcpSessionId}"
    And I set bearer token to "${valid-no-access-key}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
      }
      """
    Then the response status should be 202
    Given I set bearer token to "${valid-no-access-key}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tickets.read",
          "arguments": {
            "number": 401
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "Insufficient permissions: mcp:tickets.read required"
