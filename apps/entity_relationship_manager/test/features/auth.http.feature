@http
Feature: Authentication and Authorization API
  As a platform security engineer
  I want to verify that the ERM API enforces authentication and workspace-scoped authorization
  So that only authorized users can access and modify graph data within their workspaces

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Authentication: missing or invalid tokens
  # ===========================================================================

  Scenario: Request without Authorization header returns 401
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with invalid bearer token returns 401
    Given I set bearer token to "invalid-token-12345"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with expired token returns 401
    # Assumes: expired-token-ws-001 is a valid but expired token
    Given I set bearer token to "${expired-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with revoked API key returns 401
    Given I set bearer token to "${revoked-key-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "unauthorized"

  Scenario: Request with malformed Authorization header returns 401
    Given I set header "Authorization" to "NotBearer some-token"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
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

  Scenario: User without workspace membership gets 403
    # Assumes: non-member-token belongs to a user who is NOT a member of ws-001
    Given I set bearer token to "${non-member-token}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "forbidden"

  Scenario: User cannot access another workspace's schema
    # Assumes: admin-token-ws-001 has access to ws-001 only, not ws-002
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/schema"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "forbidden"

  # ===========================================================================
  # Role-based access: owner/admin vs member vs guest
  # ===========================================================================

  # --- Schema operations (admin/owner only for writes, all roles for reads) ---

  Scenario: Owner can update schema
    Given I set bearer token to "${owner-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response should be successful

  Scenario: Admin can update schema
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "TestEntity", "properties": [{"name": "name", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response should be successful

  Scenario: Member cannot update schema
    Given I set bearer token to "${member-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/schema" with body:
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
    Given I set bearer token to "${guest-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/schema" with body:
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
    Given I set bearer token to "${owner-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Owner Created"}
      }
      """
    Then the response status should be 201

  Scenario: Admin can create entities
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Admin Created"}
      }
      """
    Then the response status should be 201

  Scenario: Member can create entities
    Given I set bearer token to "${member-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Member Created"}
      }
      """
    Then the response status should be 201

  Scenario: Guest cannot create entities
    Given I set bearer token to "${guest-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Guest Attempt"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest can read entities
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest can read a single entity
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${personId}"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest cannot update entities
    Given I set bearer token to "${guest-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/entities/${personId}" with body:
      """
      {
        "properties": {"full_name": "Guest Hack"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot delete entities
    Given I set bearer token to "${guest-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/entities/${personId}"
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  # --- Edge operations ---

  Scenario: Guest cannot create edges
    Given I set bearer token to "${guest-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
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
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200

  Scenario: Guest cannot update edges
    Given I set bearer token to "${guest-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/edges/${employsEdgeId}" with body:
      """
      {
        "properties": {"role": "contractor"}
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot delete edges
    Given I set bearer token to "${guest-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/edges/${employsEdgeId}"
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  # --- Traversal: all roles can read ---

  Scenario: Guest can traverse the graph
    Given I set bearer token to "${guest-token-ws-001}"
    And I set query param "start_id" to "${personId}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200

  Scenario: Guest can view neighbors
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${personId}/neighbors"
    Then the response status should be 200

  Scenario: Guest can find paths
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${personId}/paths/${personId2}"
    Then the response status should be 200

  # ===========================================================================
  # Cross-workspace isolation: data does not leak between workspaces
  # ===========================================================================

  Scenario: Entity from workspace A is not visible in workspace B
    # Assumes: personId belongs to ws-001
    Given I set bearer token to "${admin-token-ws-002}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/entities/${personId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Edge from workspace A is not visible in workspace B
    Given I set bearer token to "${admin-token-ws-002}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/edges/${employsEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Traversal in workspace B does not return workspace A data
    Given I set bearer token to "${admin-token-ws-002}"
    And I set query param "start_id" to "${personId}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/traverse"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ===========================================================================
  # Error responses should not leak sensitive information
  # ===========================================================================

  Scenario: 404 for cross-workspace access does not reveal entity existence
    # Returns 404 (not 403) to avoid leaking that the entity exists in another workspace
    Given I set bearer token to "${admin-token-ws-002}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/entities/${personId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"
    And the response body path "$.message" should not exist

  Scenario: 401 response does not reveal internal details
    Given I set bearer token to "invalid-token"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 401
    And the response body path "$.error" should equal "unauthorized"
    And the response body path "$.stack_trace" should not exist
    And the response body path "$.internal" should not exist
