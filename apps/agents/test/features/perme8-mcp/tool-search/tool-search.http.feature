@http
Feature: MCP Tool Search — HTTP API
  As an LLM agent
  I want to discover what MCP tools are available on the perme8-mcp server
  So that I can understand what capabilities are accessible and how to use them

  The perme8-mcp server exposes a tools.search tool via JSON-RPC 2.0 over HTTP POST /.
  This tool allows agents to list all registered tools, search by keyword, and group
  results by provider. Each result includes the tool name, description, and input schema.

  All tool invocations follow the MCP protocol:
    1. Initialize handshake (method: "initialize")
    2. Initialized notification (method: "notifications/initialized")
    3. Tool calls (method: "tools/call" with name + arguments)

  The Mcp-Session-Id header returned by initialize must accompany subsequent requests.
  Auth errors return HTTP 401. Tool validation errors return HTTP 200 with result.isError: true.

  NOTE: Variables do NOT persist across scenarios in exo-bdd. Each scenario that needs an
  MCP session must perform its own initialize + initialized-notification handshake.

  # ===========================================================================
  # Authentication — tools.search respects auth
  # ===========================================================================

  Scenario: Unauthenticated tools.search request is rejected
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

  Scenario: Invalid API key for tools.search is rejected
    Given I set bearer token to "invalid-key-that-does-not-exist-at-all"
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
  # tools.search — List all tools (no filter)
  # ===========================================================================

  Scenario: List all available tools with no arguments
    # Initialize MCP session
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
    # Send initialized notification
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
    # Call tools.search with no arguments — should return all tools
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {}
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].type" should equal "text"
    # Should include tools from Jarga provider
    And the response body path "$.result.content[0].text" should contain "jarga.list_workspaces"
    And the response body path "$.result.content[0].text" should contain "jarga.create_project"
    And the response body path "$.result.content[0].text" should contain "jarga.list_documents"
    # Should include tools from Knowledge provider
    And the response body path "$.result.content[0].text" should contain "knowledge.search"
    And the response body path "$.result.content[0].text" should contain "knowledge.create"
    And the response body path "$.result.content[0].text" should contain "knowledge.traverse"
    # Should include the tools.search tool itself
    And the response body path "$.result.content[0].text" should contain "tools.search"

  Scenario: Listed tools include descriptions
    # Initialize MCP session
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
    # Send initialized notification
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
    # Call tools.search — descriptions should be present
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {}
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    # Results should include description text (markdown headings or description fields)
    And the response body path "$.result.content[0].text" should contain "Description"

  Scenario: Listed tools include input schema information
    # Initialize MCP session
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
    # Send initialized notification
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
    # Call tools.search — schema info should be present
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {}
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    # Results should include schema/parameter information
    And the response body path "$.result.content[0].text" should contain "Parameters"

  # ===========================================================================
  # tools.search — Search by keyword
  # ===========================================================================

  Scenario: Search tools by keyword matching tool names
    # Initialize MCP session
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
    # Send initialized notification
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
    # Search for "workspace" — should match jarga workspace tools
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "query": "workspace"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "jarga.list_workspaces"
    And the response body path "$.result.content[0].text" should contain "jarga.get_workspace"
    # Should NOT include unrelated tools
    And the response body path "$.result.content[0].text" should not contain "knowledge.create"
    And the response body path "$.result.content[0].text" should not contain "knowledge.traverse"

  Scenario: Search tools by keyword matching descriptions
    # Initialize MCP session
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
    # Send initialized notification
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
    # Search for "knowledge" — should match knowledge tools by name/description
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "query": "knowledge"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "knowledge.search"
    And the response body path "$.result.content[0].text" should contain "knowledge.create"

  Scenario: Search with non-matching keyword returns no tools
    # Initialize MCP session
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
    # Send initialized notification
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
    # Search for a nonsensical term
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "query": "nonexistent_xyz_tool_999"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "No tools found"

  # ===========================================================================
  # tools.search — Group by provider
  # ===========================================================================

  Scenario: Group tools by provider
    # Initialize MCP session
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
    # Send initialized notification
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
    # Call tools.search with group_by_provider
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "group_by_provider": true
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    # Results should be grouped by provider name
    And the response body path "$.result.content[0].text" should contain "JargaToolProvider"
    And the response body path "$.result.content[0].text" should contain "KnowledgeToolProvider"
    # Jarga tools should appear under Jarga heading
    And the response body path "$.result.content[0].text" should contain "jarga.list_workspaces"
    # Knowledge tools should appear under Knowledge heading
    And the response body path "$.result.content[0].text" should contain "knowledge.search"

  Scenario: Group by provider with keyword filter
    # Initialize MCP session
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
    # Send initialized notification
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
    # Search for "create" grouped by provider — should match in both providers
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "query": "create",
            "group_by_provider": true
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "jarga.create_project"
    And the response body path "$.result.content[0].text" should contain "jarga.create_document"
    And the response body path "$.result.content[0].text" should contain "knowledge.create"

  # ===========================================================================
  # tools.search — tools.search discovers itself
  # ===========================================================================

  Scenario: The tools.search tool appears in its own results
    # Initialize MCP session
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
    # Send initialized notification
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
    # Search for "search" — should include tools.search itself
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "tools.search",
          "arguments": {
            "query": "search"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "tools.search"
    And the response body path "$.result.content[0].text" should contain "knowledge.search"

  # ===========================================================================
  # tools.search — Permission enforcement
  # ===========================================================================

  Scenario: Revoked API key is rejected for tools.search
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
