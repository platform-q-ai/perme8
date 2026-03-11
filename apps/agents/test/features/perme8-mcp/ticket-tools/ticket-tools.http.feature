@http
Feature: Ticket MCP Tools - HTTP API
  As an API consumer
  I want to manage GitHub issues through ticket MCP tools over JSON-RPC
  So that agents can read, list, create, update, close, and organize issues consistently

  The ticket MCP endpoint uses JSON-RPC 2.0 over HTTP POST /.
  Each tool scenario follows this MCP flow:
    1. Initialize request (method: "initialize")
    2. Initialized notification (method: "notifications/initialized")
    3. Tool call request (method: "tools/call")

  The initialize response returns an Mcp-Session-Id header that must be sent
  on all subsequent requests in the scenario.

  NOTE: Variables do NOT persist across scenarios in exo-bdd.
  NOTE: MCP tool responses return Markdown text in result.content[0].text.

  # ==========================================================================
  # ticket.read
  # ==========================================================================

  Scenario: Read an issue by number
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
        "id": 101
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
          "name": "ticket.read",
          "arguments": {
            "number": 1
          }
        },
        "id": 102
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].type" should equal "text"
    And the response body path "$.result.content[0].text" should contain "Title"
    And the response body path "$.result.content[0].text" should contain "Labels"
    And the response body path "$.result.content[0].text" should contain "State"

  Scenario: Read non-existent issue
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
        "id": 103
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
          "name": "ticket.read",
          "arguments": {
            "number": 999999
          }
        },
        "id": 104
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Read missing required number param
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
        "id": 105
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
          "name": "ticket.read",
          "arguments": {}
        },
        "id": 106
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.list
  # ==========================================================================

  Scenario: List issues with no filters
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
        "id": 107
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
          "name": "ticket.list",
          "arguments": {}
        },
        "id": 108
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Issue"

  Scenario: List issues filtered by state
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
        "id": 109
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
          "name": "ticket.list",
          "arguments": {
            "state": "open"
          }
        },
        "id": 110
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: List issues filtered by labels
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
        "id": 111
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
          "name": "ticket.list",
          "arguments": {
            "labels": ["enhancement"]
          }
        },
        "id": 112
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "enhancement"

  Scenario: List issues with search query
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
        "id": 113
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
          "name": "ticket.list",
          "arguments": {
            "query": "MCP"
          }
        },
        "id": 114
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  # ==========================================================================
  # ticket.create
  # ==========================================================================

  Scenario: Create issue with title and body
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
        "id": 115
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
          "name": "ticket.create",
          "arguments": {
            "title": "Test issue from exo-bdd",
            "body": "Automated test issue."
          }
        },
        "id": 116
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should match ".*#[0-9]+.*"

  Scenario: Create issue with labels
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
        "id": 117
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
          "name": "ticket.create",
          "arguments": {
            "title": "Labeled test issue",
            "body": "Has labels.",
            "labels": ["test"]
          }
        },
        "id": 118
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Create fails without title
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
        "id": 119
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
          "name": "ticket.create",
          "arguments": {
            "body": "No title"
          }
        },
        "id": 120
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.update
  # ==========================================================================

  Scenario: Update issue title
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
        "id": 121
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
          "name": "ticket.update",
          "arguments": {
            "number": 1,
            "title": "Updated title"
          }
        },
        "id": 122
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Update non-existent issue
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
        "id": 123
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
          "name": "ticket.update",
          "arguments": {
            "number": 999999,
            "title": "Nope"
          }
        },
        "id": 124
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Update missing number
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
        "id": 125
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
          "name": "ticket.update",
          "arguments": {
            "title": "No number"
          }
        },
        "id": 126
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.close
  # ==========================================================================

  Scenario: Close issue with comment
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
        "id": 127
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
          "name": "ticket.close",
          "arguments": {
            "number": 1,
            "comment": "Closing via MCP"
          }
        },
        "id": 128
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Close non-existent issue
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
        "id": 129
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
          "name": "ticket.close",
          "arguments": {
            "number": 999999
          }
        },
        "id": 130
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true

  Scenario: Close missing number
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
        "id": 131
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
          "name": "ticket.close",
          "arguments": {}
        },
        "id": 132
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.comment
  # ==========================================================================

  Scenario: Add comment to issue
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
        "id": 133
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
          "name": "ticket.comment",
          "arguments": {
            "number": 1,
            "body": "Test comment from exo-bdd"
          }
        },
        "id": 134
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Comment on non-existent issue
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
        "id": 135
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
          "name": "ticket.comment",
          "arguments": {
            "number": 999999,
            "body": "Nope"
          }
        },
        "id": 136
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true

  Scenario: Comment missing body
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
        "id": 137
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
          "name": "ticket.comment",
          "arguments": {
            "number": 1
          }
        },
        "id": 138
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.add_sub_issue
  # ==========================================================================

  Scenario: Add sub-issue
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
        "id": 139
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
          "name": "ticket.add_sub_issue",
          "arguments": {
            "parent_number": 1,
            "child_number": 2
          }
        },
        "id": 140
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Add sub-issue missing params
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
        "id": 141
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
          "name": "ticket.add_sub_issue",
          "arguments": {}
        },
        "id": 142
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # ticket.remove_sub_issue
  # ==========================================================================

  Scenario: Remove sub-issue
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
        "id": 143
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
          "name": "ticket.remove_sub_issue",
          "arguments": {
            "parent_number": 1,
            "child_number": 2
          }
        },
        "id": 144
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false

  Scenario: Remove sub-issue missing params
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
        "id": 145
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
          "name": "ticket.remove_sub_issue",
          "arguments": {}
        },
        "id": 146
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # Permission enforcement
  # ==========================================================================

  Scenario: Permission denied for ticket.read
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
        "id": 147
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
          "name": "ticket.read",
          "arguments": {
            "number": 1
          }
        },
        "id": 148
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "Insufficient permissions"
    And the response body path "$.result.content[0].text" should contain "mcp:ticket.read"
