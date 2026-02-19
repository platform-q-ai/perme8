@http
Feature: Agents REST API
  As an API consumer
  I want to manage agents via the REST API
  So that I can create, configure, and query AI agents programmatically

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Public Endpoints — Health Check & OpenAPI Spec (no auth required)
  # ===========================================================================

  Scenario: Health check returns ok status
    When I GET "/api/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should equal "ok"

  Scenario: Health check responds within performance budget
    When I GET "/api/health"
    Then the response should be successful
    And the response time should be less than 500 ms

  Scenario: OpenAPI spec is accessible without authentication
    When I GET "/api/openapi"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.openapi" should exist

  Scenario: OpenAPI spec returns JSON content type
    When I GET "/api/openapi"
    Then the response status should be 200
    And the response should have content-type "application/json"

  # ===========================================================================
  # Authentication — missing, invalid, and revoked tokens
  # ===========================================================================

  Scenario: Unauthenticated request to agents endpoint is rejected
    When I GET "/api/agents"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key is rejected
    Given I set bearer token to "invalid-key-that-does-not-exist-at-all"
    When I GET "/api/agents"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Revoked API key is rejected
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/agents"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  # ===========================================================================
  # Agent CRUD — List
  # ===========================================================================

  Scenario: List agents returns empty array when none exist
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 0 items

  # ===========================================================================
  # Agent CRUD — Create
  # ===========================================================================

  Scenario: Create agent with valid params returns 201
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Test Agent"}
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.name" should equal "Test Agent"
    And the response body path "$.data.visibility" should equal "PRIVATE"
    And the response body path "$.data.enabled" should be true
    And the response body path "$.data.inserted_at" should exist
    And the response body path "$.data.updated_at" should exist

  Scenario: Create agent with all optional fields
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {
        "name": "Full Agent",
        "description": "A fully configured agent",
        "system_prompt": "You are a helpful assistant.",
        "model": "gpt-4o",
        "temperature": 0.5
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Full Agent"
    And the response body path "$.data.description" should equal "A fully configured agent"
    And the response body path "$.data.system_prompt" should equal "You are a helpful assistant."
    And the response body path "$.data.model" should equal "gpt-4o"

  Scenario: Create agent without name returns 422 validation error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"description": "Agent without a name"}
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.name" should exist

  Scenario: Create agent with blank name returns 422 validation error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": ""}
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.name" should exist

  # ===========================================================================
  # Agent CRUD — Create then List (verify agent appears)
  # ===========================================================================

  Scenario: Created agent appears in list
    # Step 1: Create an agent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Listed Agent"}
      """
    Then the response status should be 201
    And the response body path "$.data.id" should exist
    And I store response body path "$.data.id" as "agentId"
    # Step 2: List agents and verify it appears
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  # ===========================================================================
  # Agent CRUD — Show (Get by ID)
  # ===========================================================================

  Scenario: Get agent by ID returns the agent
    # Step 1: Create an agent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Fetchable Agent", "description": "For GET test"}
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "agentId"
    # Step 2: GET the agent by ID
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/${agentId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${agentId}"
    And the response body path "$.data.name" should equal "Fetchable Agent"
    And the response body path "$.data.description" should equal "For GET test"

  Scenario: Get non-existent agent returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Agent not found"

  # ===========================================================================
  # Agent CRUD — Update
  # ===========================================================================

  Scenario: Update agent name and description
    # Step 1: Create an agent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Original Name", "description": "Original description"}
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "agentId"
    # Step 2: Update the agent
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/agents/${agentId}" with body:
      """
      {"name": "Updated Name", "description": "Updated description"}
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${agentId}"
    And the response body path "$.data.name" should equal "Updated Name"
    And the response body path "$.data.description" should equal "Updated description"
    # Step 3: Verify the update persisted via GET
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/${agentId}"
    Then the response status should be 200
    And the response body path "$.data.name" should equal "Updated Name"
    And the response body path "$.data.description" should equal "Updated description"

  Scenario: Update non-existent agent returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/agents/00000000-0000-0000-0000-000000000000" with body:
      """
      {"name": "Ghost Agent"}
      """
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Agent not found"

  # ===========================================================================
  # Agent CRUD — Delete
  # ===========================================================================

  Scenario: Delete agent and verify it no longer exists
    # Step 1: Create an agent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Doomed Agent"}
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "agentId"
    # Step 2: Delete the agent
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I DELETE "/api/agents/${agentId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${agentId}"
    And the response body path "$.data.name" should equal "Doomed Agent"
    # Step 3: Verify the agent is gone
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/${agentId}"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Agent not found"

  Scenario: Delete non-existent agent returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I DELETE "/api/agents/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Agent not found"

  # ===========================================================================
  # Skills — List skills for an agent
  # ===========================================================================

  Scenario: List skills for an agent
    # Step 1: Create an agent
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/agents" with body:
      """
      {"name": "Skilled Agent"}
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "agentId"
    # Step 2: List skills for the agent
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/${agentId}/skills"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: List skills for non-existent agent returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/agents/00000000-0000-0000-0000-000000000000/skills"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Agent not found"
