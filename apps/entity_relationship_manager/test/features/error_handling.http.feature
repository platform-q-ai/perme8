@http
Feature: Error Handling and Validation API
  As an API consumer
  I want the ERM API to return clear, structured error responses
  So that I can diagnose and fix issues in my API integrations

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Setup: create entities needed by this feature file
  # Variables do NOT persist across feature files, so we must create our own.
  # ===========================================================================

  Scenario: Setup - ensure schema exists
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {
            "name": "Person",
            "properties": [
              {"name": "full_name", "type": "string", "required": true, "constraints": {"min_length": 1, "max_length": 255}},
              {"name": "email", "type": "string", "required": false, "constraints": {"pattern": "^[^@]+@[^@]+$"}},
              {"name": "age", "type": "integer", "required": false, "constraints": {"min": 0, "max": 200}}
            ]
          },
          {
            "name": "Company",
            "properties": [
              {"name": "name", "type": "string", "required": true, "constraints": {"min_length": 1, "max_length": 255}},
              {"name": "founded_year", "type": "integer", "required": false, "constraints": {"min": 1800, "max": 2100}}
            ]
          }
        ],
        "edge_types": [
          {
            "name": "EMPLOYS",
            "properties": [
              {"name": "since", "type": "datetime", "required": false},
              {"name": "role", "type": "string", "required": false, "constraints": {"enum": ["full-time", "part-time", "contractor"]}}
            ]
          },
          {"name": "KNOWS", "properties": []}
        ]
      }
      """
    Then the response should be successful

  Scenario: Setup - create Person entity (personId)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Error Test Alice", "email": "error.alice@example.com"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "personId"

  # ===========================================================================
  # Invalid JSON and malformed requests
  # ===========================================================================

  @raw-http
  Scenario: Request with invalid JSON body returns 400
    # NOTE: Tagged @raw-http because Playwright HTTP adapter may encode string
    # bodies differently than curl. Verified via curl that server returns 400.
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST raw to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {this is not valid json}
      """
    Then the response status should be 400
    And the response body should be valid JSON
    And the response body path "$.error" should equal "bad_request"

  Scenario: Request with empty body to POST endpoint returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 422
    And the response body should be valid JSON

  # ===========================================================================
  # Invalid UUID format
  # ===========================================================================

  Scenario: Invalid UUID format in entity ID returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/not-a-uuid"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "id"

  Scenario: Invalid UUID format in workspace ID returns 400
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/not-a-uuid/entities"
    Then the response status should be 400
    And the response body should be valid JSON
    And the response body path "$.error" should equal "bad_request"

  # ===========================================================================
  # Not found errors
  # ===========================================================================

  Scenario: Non-existent entity returns 404 with structured error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  Scenario: Non-existent edge returns 404 with structured error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  Scenario: Non-existent route returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/nonexistent"
    Then the response status should be 404
    And the response body should be valid JSON

  # ===========================================================================
  # Schema validation error details
  # ===========================================================================

  Scenario: Entity validation error includes field, message, and constraint
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "age": -5
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    And the response body path "$.errors[0].field" should exist
    And the response body path "$.errors[0].message" should exist
    And the response body path "$.errors[0].constraint" should exist

  Scenario: Multiple validation errors are returned together
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "email": "not-an-email",
          "age": -5
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    # Should include errors for missing full_name, invalid email pattern, and invalid age

  Scenario: Validation error for wrong property type
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Alice",
          "age": "not-a-number"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "age"
    And the response body path "$.errors[0].message" should contain "integer"

  Scenario: Validation error for string exceeding max_length
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "full_name"
    And the response body path "$.errors[0].constraint" should equal "max_length"

  # ===========================================================================
  # Schema version conflict
  # ===========================================================================

  Scenario: Concurrent schema update returns 409 with conflict details
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "version": 0,
        "entity_types": [
          {"name": "Stale", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 409
    And the response body should be valid JSON
    And the response body path "$.error" should equal "version_conflict"
    And the response body path "$.message" should exist

  # ===========================================================================
  # No schema configured
  # ===========================================================================

  Scenario: Entity creation in workspace without schema returns descriptive error
    Given I set bearer token to "${valid-key-engineering-only}"
    When I POST to "/api/v1/workspaces/${workspace-id-engineering}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Nobody"}
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should equal "no_schema_configured"
    And the response body path "$.message" should contain "schema"

  Scenario: Edge creation in workspace without schema returns descriptive error
    Given I set bearer token to "${valid-key-engineering-only}"
    When I POST to "/api/v1/workspaces/${workspace-id-engineering}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "00000000-0000-0000-0000-000000000001",
        "target_id": "00000000-0000-0000-0000-000000000002",
        "properties": {}
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should equal "no_schema_configured"

  # ===========================================================================
  # Method not allowed
  # ===========================================================================

  Scenario: PATCH on schema endpoint returns 404 (no such route)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I send a PATCH request to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {"entity_types": []}
      """
    Then the response status should be 404

  # ===========================================================================
  # Invalid query parameters
  # ===========================================================================

  Scenario: Negative pagination limit returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set query param "limit" to "-1"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "limit"

  Scenario: Pagination limit exceeding maximum returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set query param "limit" to "1000"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "limit"
    And the response body path "$.message" should contain "500"

  Scenario: Invalid direction parameter returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set query param "direction" to "sideways"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}/neighbors"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "direction"

  Scenario: Traversal depth exceeding maximum returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set the following query params:
      | start_id | ${personId} |
      | depth    | 15           |
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/traverse"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "depth"
    And the response body path "$.message" should contain "10"

  Scenario: Non-numeric depth parameter returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set the following query params:
      | start_id | ${personId} |
      | depth    | abc          |
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/traverse"
    Then the response status should be 422
    And the response body should be valid JSON

  # ===========================================================================
  # Bulk operation error details
  # ===========================================================================

  Scenario: Bulk errors include item index for traceability
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "partial",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Valid"}},
          {"type": "Person", "properties": {"email": "no-name"}},
          {"type": "Person", "properties": {"full_name": "Also Valid"}},
          {"type": "UnknownType", "properties": {"name": "Ghost"}}
        ]
      }
      """
    Then the response status should be 207
    And the response body should be valid JSON
    And the response body path "$.errors[0].index" should equal 1
    And the response body path "$.errors[1].index" should equal 3
    And the response body path "$.errors[0].errors" should exist
    And the response body path "$.errors[1].errors" should exist

  # ===========================================================================
  # Graph database unavailability
  # ===========================================================================

  @neo4j
  Scenario: Neo4j unavailability returns 503 with structured error
    # This scenario tests the circuit breaker / graceful degradation
    # When Neo4j is down, entity operations should return 503
    # Assumes: Neo4j is intentionally stopped for this test
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 503
    And the response body should be valid JSON
    And the response body path "$.error" should equal "graph_unavailable"
    And the response body path "$.message" should equal "Graph database is temporarily unavailable"

  # ===========================================================================
  # Health check reports Neo4j status
  # ===========================================================================

  Scenario: Health check shows healthy status when Neo4j is available
    When I GET "/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should equal "ok"
    And the response body path "$.neo4j" should equal "connected"

  @neo4j
  Scenario: Health check shows degraded status when Neo4j is unavailable
    # Assumes: Neo4j is intentionally stopped for this test
    When I GET "/health"
    Then the response status should be 503
    And the response body should be valid JSON
    And the response body path "$.status" should equal "degraded"
    And the response body path "$.neo4j" should equal "disconnected"

  # ===========================================================================
  # Content-Type validation
  # ===========================================================================

  Scenario: Request with wrong Content-Type returns 415
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set header "Content-Type" to "text/plain"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {"type": "Person", "properties": {"full_name": "test"}}
      """
    Then the response status should be 415
    And the response body should be valid JSON
    And the response body path "$.error" should contain "content_type"

  # ===========================================================================
  # Response format consistency
  # ===========================================================================

  Scenario: All success responses include data key
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response should have content-type "application/json"

  Scenario: All error responses include error key
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should exist
    And the response should have content-type "application/json"

  Scenario: Error responses do not leak stack traces
    Given I set bearer token to "invalid"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.stack_trace" should not exist
    And the response body path "$.exception" should not exist
    And the response body path "$.internal" should not exist
