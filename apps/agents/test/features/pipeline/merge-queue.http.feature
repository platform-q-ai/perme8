@http @pipeline @merge-queue @phase-8
Feature: Pipeline Phase 8 - Merge Queue (HTTP API)
  As Perme8 pipeline automation
  I want ready pull requests to enter a merge queue and be validated against the merge result before merge
  So that only queue-approved, revalidated changes are merged to main

  The internal pipeline surface is exercised through MCP JSON-RPC over HTTP POST /.
  This early-pipeline feature keeps request shapes generic and uses clearly marked
  pipeline and PR operations without locking down a final endpoint contract.

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
        "id": 8801
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

  Scenario: Queue accepts a ready pull request
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pipeline.merge_queue.evaluate_readiness",
          "arguments": {
            "pull_request": {"number": 401},
            "required_stages_passed": true,
            "approved_review": true
          }
        },
        "id": 8802
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should match ".*(enter|entered|queued).*"

  Scenario: Queue rejects a pull request that is not ready
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pipeline.merge_queue.evaluate_readiness",
          "arguments": {
            "pull_request": {"number": 402},
            "required_stages_passed": false,
            "approved_review": false
          }
        },
        "id": 8803
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be true
    And the response body path "$.result.content[0].text" should contain "merge requirements are not satisfied"

  Scenario: Pre-merge validation runs against the merge result
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pipeline.merge_queue.start_pre_merge_validation",
          "arguments": {
            "queued_pull_request": {"number": 403}
          }
        },
        "id": 8804
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "merge result"
    And the response body path "$.result.content[0].text" should contain "tracked"

  Scenario: Successful validation triggers auto-merge
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pipeline.merge_queue.complete_merge_execution",
          "arguments": {
            "pull_request": {"number": 404},
            "pre_merge_validation": "passed"
          }
        },
        "id": 8805
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "merged"
    And the response body path "$.result.content[0].text" should contain "main"

  Scenario: YAML policy drives queue requirements
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Mcp-Session-Id" to "${mcpSessionId}"
    When I POST to "/" with body:
      """
      {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "pipeline.merge_queue.load_policy",
          "arguments": {
            "policy_source": "pipeline_yaml",
            "required_stages": ["build", "test", "review"],
            "strategy": "merge_queue"
          }
        },
        "id": 8806
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.result.isError" should be false
    And the response body path "$.result.content[0].text" should contain "required stages"
    And the response body path "$.result.content[0].text" should contain "strategy"
