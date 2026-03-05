@http
Feature: API key permission enforcement on REST API
  As an API consumer
  I want agents endpoints to enforce API key permission scopes
  So that authenticated keys can only perform authorized operations

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # Assumes config variables for permission-focused API keys:
  # - api-key-agents-read
  # - api-key-agents-write
  # - api-key-agents-query
  # - api-key-agents-wildcard
  # - api-key-full-access                (equivalent to "*")
  # - api-key-nil-permissions            (permissions field is nil)
  # - api-key-empty-permissions          (permissions is [])
  # - api-key-invalid

  Scenario: API key with agents:read permission can list agents
    Given I set bearer token to "${api-key-agents-read}"
    When I GET "/api/agents"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: API key without agents:read permission is denied listing agents
    Given I set bearer token to "${api-key-agents-write}"
    When I GET "/api/agents"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "insufficient_permissions"
    And the response body path "$.required" should equal "agents:read"

  Scenario: API key with agents:write permission can create an agent
    Given I set bearer token to "${api-key-agents-write}"
    When I POST to "/api/agents" with body:
      """
      {"name": "permission-write-agent"}
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.name" should equal "permission-write-agent"

  Scenario: API key without agents:write permission cannot create an agent
    Given I set bearer token to "${api-key-agents-read}"
    When I POST to "/api/agents" with body:
      """
      {"name": "should-not-create"}
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "insufficient_permissions"
    And the response body path "$.required" should equal "agents:write"

  Scenario: API key with wildcard permission has full access
    Given I set bearer token to "${api-key-full-access}"
    When I GET "/api/agents"
    Then the response status should be 200
    And the response body path "$.data" should exist
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${api-key-full-access}"
    When I POST to "/api/agents" with body:
      """
      {"name": "wildcard-full-access-agent"}
      """
    Then the response status should be 201
    And the response body path "$.data.id" should exist

  Scenario: API key with nil permissions has full access for backward compatibility
    Given I set bearer token to "${api-key-nil-permissions}"
    When I GET "/api/agents"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: API key with empty permissions list is denied all access
    Given I set bearer token to "${api-key-empty-permissions}"
    When I GET "/api/agents"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "insufficient_permissions"

  Scenario: API key with agents:query permission can query an agent
    Given I set bearer token to "${api-key-full-access}"
    When I POST to "/api/agents" with body:
      """
      {"name": "queryable-agent"}
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "agentId"
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${api-key-agents-query}"
    When I POST to "/api/agents/${agentId}/query" with body:
      """
      {"input": "Hello from query scope test"}
      """
    Then the response should be successful

  Scenario: API key with category wildcard matches sub-scopes
    Given I set bearer token to "${api-key-agents-wildcard}"
    When I GET "/api/agents"
    Then the response status should be 200
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${api-key-agents-wildcard}"
    When I POST to "/api/agents" with body:
      """
      {"name": "category-wildcard-agent"}
      """
    Then the response status should be 201

  Scenario: Permission check returns 403 not 401 for authenticated but unauthorized key
    Given I set bearer token to "${api-key-agents-read}"
    When I POST to "/api/agents" with body:
      """
      {"name": "forbidden-write-attempt"}
      """
    Then the response status should be 403
    And the response status should not be 401
    And the response body path "$.error" should equal "insufficient_permissions"

  Scenario: Unauthenticated request returns 401 before permission check
    When I GET "/api/agents"
    Then the response status should be 401

  Scenario: Invalid API key is rejected before permission checks
    Given I set bearer token to "${api-key-invalid}"
    When I GET "/api/agents"
    Then the response status should be 401

  Scenario: Create API key with permissions via REST API
    Given I set bearer token to "${api-key-full-access}"
    When I POST to "/api/api-keys" with body:
      """
      {
        "name": "scoped-read-key",
        "permissions": ["agents:read", "mcp:knowledge.*"]
      }
      """
    Then the response should be successful
    And the response body should be valid JSON
    And the response body should contain "agents:read"
    And the response body should contain "mcp:knowledge.*"

  Scenario: Update API key permissions via REST API
    Given I set bearer token to "${api-key-full-access}"
    When I POST to "/api/api-keys" with body:
      """
      {
        "name": "updatable-scoped-key",
        "permissions": ["agents:read"]
      }
      """
    Then the response should be successful
    And I store response body path "$.data.id" as "managedApiKeyId"
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${api-key-full-access}"
    When I PATCH to "/api/api-keys/${managedApiKeyId}" with body:
      """
      {
        "permissions": ["agents:read", "agents:write"]
      }
      """
    Then the response should be successful
    And the response body should be valid JSON
    And the response body should contain "agents:read"
    And the response body should contain "agents:write"
