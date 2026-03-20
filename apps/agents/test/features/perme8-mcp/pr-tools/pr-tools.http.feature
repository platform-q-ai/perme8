@http
Feature: Pull Request MCP Tools - HTTP API
  As an API consumer
  I want to manage internal pull requests through MCP tools over JSON-RPC
  So that agents can create, review, and finalize PR pipeline artifacts consistently

  The PR MCP endpoint uses JSON-RPC 2.0 over HTTP POST /.
  Each scenario follows this MCP flow:
    1. Initialize request (method: "initialize")
    2. Initialized notification (method: "notifications/initialized")
    3. Tool call request (method: "tools/call")

  The initialize response returns an Mcp-Session-Id header that must be sent
  on all subsequent requests in the scenario.

  NOTE: Variables do NOT persist across scenarios in exo-bdd.
  NOTE: MCP tool responses return Markdown text in result.content[0].text.

  Background:
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
        "id": 2001
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

  # ==========================================================================
  # pr.create
  # ==========================================================================

  Scenario: Create an internal pull request
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.create",
          "arguments": {
            "source_branch": "feature/mcp-pr-tools-smoke",
            "target_branch": "main",
            "title": "Add MCP PR tools smoke coverage",
            "body": "Early-pipeline validation for internal PR artifact flow.",
            "linked_ticket": 101
          }
        },
        "id": 2002
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].type" should equal "text"
    And the response body path "$.result.content[0].text" should contain "PR"
    And the response body path "$.result.content[0].text" should match ".*(draft|open).*"

  Scenario: Reject create when required fields are missing
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.create",
          "arguments": {
            "title": "Missing branches"
          }
        },
        "id": 2003
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # pr.read
  # ==========================================================================

  Scenario: Read a pull request by number
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.read",
          "arguments": {
            "number": 301
          }
        },
        "id": 2004
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "Title"
    And the response body path "$.result.content[0].text" should contain "source"
    And the response body path "$.result.content[0].text" should contain "target"
    And the response body path "$.result.content[0].text" should contain "status"

  Scenario: Read missing pull request returns not-found
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.read",
          "arguments": {
            "number": 999999
          }
        },
        "id": 2005
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  # ==========================================================================
  # pr.list
  # ==========================================================================

  Scenario: List pull requests with state filter
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.list",
          "arguments": {
            "state": "open"
          }
        },
        "id": 2006
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "PR"

  # ==========================================================================
  # pr.update
  # ==========================================================================

  Scenario: Update pull request metadata
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.update",
          "arguments": {
            "number": 301,
            "title": "Refine MCP PR tool contract",
            "body": "Update metadata to align with internal pipeline behavior.",
            "status": "in_review"
          }
        },
        "id": 2007
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "in_review"

  Scenario: Reject update when args are malformed
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.update",
          "arguments": {
            "number": "not-a-number",
            "status": "open"
          }
        },
        "id": 2008
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # pr.diff
  # ==========================================================================

  Scenario: Get pull request diff
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.diff",
          "arguments": {
            "number": 301
          }
        },
        "id": 2009
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "diff"

  Scenario: Diff missing pull request returns not-found
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.diff",
          "arguments": {
            "number": 999999
          }
        },
        "id": 2010
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  # ==========================================================================
  # pr.comment
  # ==========================================================================

  Scenario: Add a review comment to a pull request
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.comment",
          "arguments": {
            "number": 301,
            "body": "Please rename this helper for clarity.",
            "path": "lib/agents/mcp/pr_tools.ex",
            "line": 42
          }
        },
        "id": 2011
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "comment"

  # ==========================================================================
  # pr.review
  # ==========================================================================

  Scenario: Submit an approve review
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.review",
          "arguments": {
            "number": 301,
            "event": "approve",
            "body": "Looks good to merge."
          }
        },
        "id": 2012
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "approved"

  Scenario: Reject review with invalid event
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.review",
          "arguments": {
            "number": 301,
            "event": "ship-it"
          }
        },
        "id": 2013
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response body path "$.error.code" should equal -32602
    And the response body path "$.result" should not exist

  # ==========================================================================
  # pr.merge
  # ==========================================================================

  Scenario: Merge an approved pull request
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.merge",
          "arguments": {
            "number": 305,
            "merge_method": "merge"
          }
        },
        "id": 2014
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "merged"

  Scenario: Merge missing pull request returns not-found
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.merge",
          "arguments": {
            "number": 999999
          }
        },
        "id": 2015
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"

  # ==========================================================================
  # pr.close
  # ==========================================================================

  Scenario: Close a pull request without merging
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.close",
          "arguments": {
            "number": 306
          }
        },
        "id": 2016
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "closed"

  Scenario: Close missing pull request returns not-found
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pr.close",
          "arguments": {
            "number": 999999
          }
        },
        "id": 2017
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "not found"
