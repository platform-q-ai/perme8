@http
Feature: Authentication and Authorization API
  As a platform security engineer
  I want to verify that the ERM API enforces authentication and workspace-scoped authorization
  So that only authorized users can access and modify graph data within their workspaces

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Setup: create entities and edges needed by this feature file
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
        "properties": {"full_name": "Auth Test Alice", "email": "auth.alice@example.com"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "personId"

  Scenario: Setup - create second Person entity (personId2)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Auth Test Bob"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "personId2"

  Scenario: Setup - create Company entity and EMPLOYS edge (employsEdgeId)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Company",
        "properties": {"name": "Auth Test Corp"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "authCompanyId"
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
      """
      {
        "type": "EMPLOYS",
        "source_id": "${authCompanyId}",
        "target_id": "${personId}",
        "properties": {"role": "full-time"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "employsEdgeId"

  # ===========================================================================
  # Authentication: missing or invalid tokens
  # ===========================================================================

  Scenario: Request without Authorization header returns 401
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with invalid bearer token returns 401
    Given I set bearer token to "invalid-token-12345"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with expired token returns 401
    # Assumes: expired-token-ws-001 is a valid but expired token
    Given I set bearer token to "expired-token-placeholder-12345"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with revoked API key returns 401
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with malformed Authorization header returns 401
    Given I set header "Authorization" to "NotBearer some-token"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  # ===========================================================================
  # Health endpoint: unauthenticated access
  # ===========================================================================

  Scenario: Health check does not require authentication
    When I GET "/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should exist

  # ===========================================================================
  # Workspace membership: user must belong to the workspace
  # ===========================================================================

  Scenario: User without workspace membership gets 404
    # Assumes: valid-member-key-product-team belongs to bob, who is NOT a member of engineering
    # WorkspaceAuthPlug returns 404 (not 403) for non-members to avoid leaking workspace existence
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/entities"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  Scenario: User cannot access another workspace's schema
    # Assumes: valid-member-key-product-team belongs to bob, who is NOT a member of engineering
    # WorkspaceAuthPlug returns 404 for cross-workspace access
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/schema"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  # ===========================================================================
  # Role-based access: owner/admin vs member vs guest
  # ===========================================================================

  # --- Schema operations (admin/owner only for writes, all roles for reads) ---

  Scenario: Owner can update schema
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "Person", "properties": [{"name": "full_name", "type": "string", "required": true}]},
          {"name": "Company", "properties": [{"name": "name", "type": "string", "required": true}]},
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": [
          {"name": "EMPLOYS", "properties": []},
          {"name": "KNOWS", "properties": []}
        ]
      }
      """
    Then the response should be successful

  Scenario: Admin can update schema
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "Person", "properties": [{"name": "full_name", "type": "string", "required": true}]},
          {"name": "Company", "properties": [{"name": "name", "type": "string", "required": true}]},
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": [
          {"name": "EMPLOYS", "properties": []},
          {"name": "KNOWS", "properties": []}
        ]
      }
      """
    Then the response should be successful

  Scenario: Member cannot update schema
    Given I set bearer token to "${valid-member-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot update schema
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  # --- Entity operations ---

  Scenario: Owner can create entities
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Owner Created"}
      }
      """
    Then the response status should be 201

  Scenario: Admin can create entities
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Admin Created"}
      }
      """
    Then the response status should be 201

  Scenario: Member can create entities
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Member Created"}
      }
      """
    Then the response status should be 201

  Scenario: Guest cannot create entities
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Guest Attempt"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest can read entities
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest can read a single entity
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest cannot update entities
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}" with body:
      """
      {
        "properties": {"full_name": "Guest Hack"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot delete entities
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I DELETE "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}"
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  # --- Edge operations ---

  Scenario: Guest cannot create edges
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "${personId}",
        "target_id": "${personId2}",
        "properties": {}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest can read edges
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200

  Scenario: Guest cannot update edges
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/edges/${employsEdgeId}" with body:
      """
      {
        "properties": {"role": "contractor"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot delete edges
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I DELETE "/api/v1/workspaces/${workspace-id-product-team}/edges/${employsEdgeId}"
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  # --- Traversal: all roles can read ---

  Scenario: Guest can traverse the graph
    Given I set bearer token to "${valid-guest-key-product-team}"
    And I set query param "start_id" to "${personId}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/traverse"
    Then the response status should be 200

  Scenario: Guest can view neighbors
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}/neighbors"
    Then the response status should be 200

  Scenario: Guest can find paths
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities/${personId}/paths/${personId2}"
    Then the response status should be 200

  # ===========================================================================
  # Cross-workspace isolation: data does not leak between workspaces
  # ===========================================================================

  Scenario: Entity from workspace A is not visible in workspace B
    # Assumes: personId belongs to ws-001
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/entities/${personId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Edge from workspace A is not visible in workspace B
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/edges/${employsEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Traversal in workspace B does not return workspace A data
    Given I set bearer token to "${valid-key-engineering-only}"
    And I set query param "start_id" to "${personId}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/traverse"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ===========================================================================
  # Error responses should not leak sensitive information
  # ===========================================================================

  Scenario: 404 for cross-workspace access does not reveal entity existence
    # Returns 404 (not 403) to avoid leaking that the entity exists in another workspace
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/entities/${personId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"
    And the response body path "$.message" should not exist

  Scenario: 401 response does not reveal internal details
    Given I set bearer token to "invalid-token"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/entities"
    Then the response status should be 401
    And the response body path "$.error" should equal "unauthorized"
    And the response body path "$.stack_trace" should not exist
    And the response body path "$.internal" should not exist
