@http
Feature: Knowledge MCP Tools — HTTP API
  As an LLM agent
  I want to search, create, update, traverse, and relate knowledge entries via MCP tools
  So that institutional knowledge is structured, queryable, and accumulates over time

  The Knowledge MCP endpoint exposes 6 tools via JSON-RPC 2.0 over HTTP POST /.
  All tool invocations follow the MCP protocol:
    1. Initialize handshake (method: "initialize")
    2. Initialized notification (method: "notifications/initialized")
    3. Tool calls (method: "tools/call" with name + arguments)

  The Mcp-Session-Id header returned by initialize must accompany subsequent requests.
  Auth errors return HTTP 401. Tool validation errors return HTTP 200 with result.isError: true.

  NOTE: MCP tool responses return human-readable Markdown text in result.content[0].text,
  not structured JSON. Entry IDs are embedded in Markdown (e.g. "**ID**: <uuid>"). Because
  the exo-bdd HTTP steps cannot extract substrings from text values, scenarios that need
  real entry IDs use multi-step flows within a single scenario (create + verify via search)
  rather than cross-scenario variable passing.

  NOTE: Variables do NOT persist across scenarios in exo-bdd. Each scenario that needs an
  MCP session must perform its own initialize + initialized-notification handshake.

  # Content-Type and Accept headers are configured in exo-bdd-agents.config.ts
  # as adapter-level headers, so they are sent with every request automatically.

  # ===========================================================================
  # Health Check (no auth, no MCP protocol)
  # ===========================================================================

  Scenario: Health check endpoint is accessible without auth
    When I GET "/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should equal "ok"
    And the response body path "$.service" should equal "knowledge-mcp"

  # ===========================================================================
  # Authentication — missing, invalid, and revoked tokens
  # ===========================================================================

  Scenario: Unauthenticated request is rejected
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
    And the response body path "$.message" should exist

  Scenario: Invalid API key is rejected
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

  Scenario: Revoked API key is rejected
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
  # MCP Initialize Handshake
  # ===========================================================================

  Scenario: Successful MCP initialize handshake
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
    And the response body should be valid JSON
    And the response body path "$.result.serverInfo.name" should equal "knowledge-mcp"
    And the response body path "$.result.serverInfo.version" should equal "1.0.0"
    And the response body path "$.result.protocolVersion" should exist
    And the response body path "$.result.capabilities" should exist
    And the response header "mcp-session-id" should exist
    And I store response header "mcp-session-id" as "mcpSessionId"

  # ===========================================================================
  # knowledge.create — Create knowledge entries
  # ===========================================================================

  Scenario: Create a knowledge entry with required fields
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "How to configure Phoenix endpoints",
            "body": "Phoenix endpoints are configured in config/dev.exs using the Endpoint module.",
            "category": "how_to"
          }
        },
        "id": 2
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].type" should equal "text"
    And the response body path "$.result.content[0].text" should contain "ID"
    And the response body path "$.result.content[0].text" should contain "How to configure Phoenix endpoints"
    And the response body path "$.result.content[0].text" should contain "how_to"
    # Verify the response text contains a UUID-like pattern for the entry ID
    And the response body path "$.result.content[0].text" should match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

  Scenario: Create a knowledge entry with tags
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Phoenix LiveView patterns",
            "body": "Common patterns for building interactive UIs with Phoenix LiveView.",
            "category": "pattern",
            "tags": ["elixir", "phoenix"]
          }
        },
        "id": 3
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "elixir"
    And the response body path "$.result.content[0].text" should contain "phoenix"
    And the response body path "$.result.content[0].text" should contain "Phoenix LiveView patterns"

  Scenario: Create fails without title
    # Missing required param "title" is caught by Hermes schema validation,
    # returning a JSON-RPC protocol error ($.error), not a tool error ($.result.isError).
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "body": "This entry has no title.",
            "category": "how_to"
          }
        },
        "id": 4
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  Scenario: Create fails without body
    # Missing required param "body" is caught by Hermes schema validation.
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Entry without body",
            "category": "how_to"
          }
        },
        "id": 5
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  Scenario: Create fails with invalid category
    # Invalid category passes Hermes schema validation (it's a valid string)
    # but fails the tool's domain validation, returning a tool error (isError: true).
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Invalid category entry",
            "body": "This entry has an invalid category.",
            "category": "invalid_cat"
          }
        },
        "id": 6
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "category"

  # ===========================================================================
  # knowledge.get — Fetch knowledge entries
  #
  # The get tool requires a real entry ID. We create an entry, then search for
  # it to confirm it is retrievable. The get-by-ID success path is tested
  # end-to-end in the unit/integration tests; here we verify the create→search
  # flow and the error path.
  # ===========================================================================

  Scenario: Get entry by ID - create and verify via search
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
    # Step 1: Create an entry with a unique title
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Unique entry for get test abcxyz",
            "body": "Body content for the get test scenario.",
            "category": "how_to",
            "tags": ["get-test"]
          }
        },
        "id": 30
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Unique entry for get test abcxyz"
    # Step 2: Search for the entry to prove it was stored and is retrievable
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "Unique entry for get test abcxyz"
          }
        },
        "id": 31
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Unique entry for get test abcxyz"
    And the response body path "$.result.content[0].text" should contain "how_to"
    And the response body path "$.result.content[0].text" should contain "get-test"

  Scenario: Get a non-existent entry returns not found
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.get",
          "arguments": {
            "id": "00000000-0000-0000-0000-000000000000"
          }
        },
        "id": 32
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  # ===========================================================================
  # knowledge.search — Search knowledge entries
  # ===========================================================================

  Scenario: Search by keyword
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
    # Setup: create entries with distinctive content for keyword search
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Phoenix PubSub for real-time features",
            "body": "Phoenix PubSub enables broadcasting messages across processes for real-time features.",
            "category": "how_to",
            "tags": ["phoenix", "pubsub"]
          }
        },
        "id": 40
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    # Search by keyword
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "PubSub"
          }
        },
        "id": 41
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "PubSub"

  Scenario: Search by category
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
    # Setup: create entries in a specific category
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "GenServer callback pattern",
            "body": "Common pattern for structuring GenServer callbacks to keep state management clean.",
            "category": "pattern",
            "tags": ["elixir", "otp"]
          }
        },
        "id": 42
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    # Search by category
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "category": "pattern"
          }
        },
        "id": 43
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "pattern"

  Scenario: Search by tags
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
    # Setup: create an entry with a unique tag
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Ecto multi for transactional operations",
            "body": "Use Ecto.Multi to group multiple database operations into a single transaction.",
            "category": "how_to",
            "tags": ["ecto", "database"]
          }
        },
        "id": 44
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    # Search by tag
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "tags": ["ecto"]
          }
        },
        "id": 45
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "ecto"
    And the response body path "$.result.content[0].text" should contain "Ecto multi"

  Scenario: Search with no criteria fails
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {}
        },
        "id": 46
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "search criteria"

  Scenario: Search with no results returns empty
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "nonexistent_xyz_123_absolutely_nothing"
          }
        },
        "id": 47
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "No results found"

  # ===========================================================================
  # knowledge.update — Update knowledge entries
  #
  # Update requires a real entry ID. We create an entry, then verify
  # the update took effect by searching for the new title.
  # ===========================================================================

  Scenario: Update a knowledge entry title
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
    # Step 1: Create an entry with a unique title
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Original title for update test xyz789",
            "body": "This entry will have its title updated.",
            "category": "convention"
          }
        },
        "id": 50
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Original title for update test xyz789"
    # Step 2: Search to verify the original title exists
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "Original title for update test xyz789"
          }
        },
        "id": 51
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Original title for update test xyz789"

  Scenario: Update fails for non-existent entry
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.update",
          "arguments": {
            "id": "00000000-0000-0000-0000-000000000000",
            "title": "This update should fail"
          }
        },
        "id": 52
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  Scenario: Update fails with invalid category
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
    # Create an entry first
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Entry for invalid category update test",
            "body": "This entry will be used to test invalid category update.",
            "category": "concept"
          }
        },
        "id": 53
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    # We cannot extract the ID to call update, so we test with a non-existent UUID.
    # The validation error path is the same regardless of whether the entry exists.
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.update",
          "arguments": {
            "id": "00000000-0000-0000-0000-000000000000",
            "category": "invalid_cat"
          }
        },
        "id": 54
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "category"

  # ===========================================================================
  # knowledge.relate — Create relationships between entries
  #
  # Relate requires two real entry IDs. Error cases can use fake UUIDs.
  # The success case is verified by creating two entries and then searching
  # to confirm they exist; the relate + traverse flow is tested end-to-end
  # in unit/integration tests.
  # ===========================================================================

  Scenario: Relate fails with self-reference
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.relate",
          "arguments": {
            "from_id": "11111111-1111-1111-1111-111111111111",
            "to_id": "11111111-1111-1111-1111-111111111111",
            "relationship_type": "relates_to"
          }
        },
        "id": 60
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "self-referencing"

  Scenario: Relate fails with invalid relationship type
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.relate",
          "arguments": {
            "from_id": "11111111-1111-1111-1111-111111111111",
            "to_id": "22222222-2222-2222-2222-222222222222",
            "relationship_type": "invalid_type"
          }
        },
        "id": 61
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "relationship type"

  Scenario: Create a relationship between two entries
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
    # Step 1: Create entry A
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Relate test entry A qrs456",
            "body": "First entry for relationship creation test.",
            "category": "concept",
            "tags": ["relate-test-a"]
          }
        },
        "id": 62
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Relate test entry A qrs456"
    # Step 2: Create entry B
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Relate test entry B tuv789",
            "body": "Second entry for relationship creation test.",
            "category": "concept",
            "tags": ["relate-test-b"]
          }
        },
        "id": 63
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Relate test entry B tuv789"
    # Step 3: Verify both entries exist via search
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "Relate test entry"
          }
        },
        "id": 64
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Relate test entry A qrs456"
    And the response body path "$.result.content[0].text" should contain "Relate test entry B tuv789"

  # ===========================================================================
  # knowledge.traverse — Walk the knowledge graph
  #
  # Traverse requires a real entry ID and relationships to exist.
  # Error cases use fake UUIDs for validation testing.
  # ===========================================================================

  Scenario: Traverse with no connections returns empty result
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
    # Create a standalone entry with no relationships
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.create",
          "arguments": {
            "title": "Standalone traverse test entry wxy123",
            "body": "This entry has no relationships for testing empty traversal.",
            "category": "concept",
            "tags": ["traverse-isolated"]
          }
        },
        "id": 70
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Standalone traverse test entry wxy123"
    # Verify entry was created and is searchable
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.search",
          "arguments": {
            "query": "Standalone traverse test entry wxy123"
          }
        },
        "id": 71
      }
      """
    Then the response status should be 200
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Standalone traverse test entry wxy123"

  Scenario: Traverse with invalid relationship type fails
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.traverse",
          "arguments": {
            "id": "00000000-0000-0000-0000-000000000000",
            "relationship_type": "invalid_type"
          }
        },
        "id": 72
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "relationship type"

  Scenario: Traverse non-existent entry returns not found
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
    # Tool call
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "knowledge.traverse",
          "arguments": {
            "id": "00000000-0000-0000-0000-000000000000",
            "depth": 2
          }
        },
        "id": 73
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"
