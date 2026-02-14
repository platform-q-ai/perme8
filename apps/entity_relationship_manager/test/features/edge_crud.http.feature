@http
Feature: Edge/Relationship CRUD API
  As an API consumer
  I want to create, read, update, and delete edges between entities via the REST API
  So that I can model relationships in my workspace's entity graph

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:workspace_id/edges — Create edge
  # ---------------------------------------------------------------------------

  Scenario: Create an EMPLOYS edge between Company and Person
    # Assumes: workspace ws-001 has schema with EMPLOYS edge type,
    #          and entities companyId (Company) and personId (Person) exist
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "EMPLOYS",
        "source_id": "${companyId}",
        "target_id": "${personId}",
        "properties": {
          "since": "2024-01-15T00:00:00Z",
          "role": "full-time"
        }
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.type" should equal "EMPLOYS"
    And the response body path "$.data.source_id" should equal "${companyId}"
    And the response body path "$.data.target_id" should equal "${personId}"
    And the response body path "$.data.properties.role" should equal "full-time"
    And the response body path "$.data.properties.since" should exist
    And the response body path "$.data.created_at" should exist
    And the response body path "$.data.deleted_at" should be null
    And I store response body path "$.data.id" as "employsEdgeId"

  Scenario: Create a KNOWS edge with no properties
    # Assumes: two Person entities exist — personId and personId2
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "${personId}",
        "target_id": "${personId2}",
        "properties": {}
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.type" should equal "KNOWS"
    And the response body path "$.data.source_id" should equal "${personId}"
    And the response body path "$.data.target_id" should equal "${personId2}"
    And I store response body path "$.data.id" as "knowsEdgeId"

  Scenario: Member can create edges
    Given I set bearer token to "${member-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "${personId}",
        "target_id": "${personId2}",
        "properties": {}
      }
      """
    Then the response status should be 201
    And the response body path "$.data.type" should equal "KNOWS"

  # ---------------------------------------------------------------------------
  # POST — Validation errors
  # ---------------------------------------------------------------------------

  Scenario: Creating edge with unconfigured type returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "INVALID_EDGE",
        "source_id": "${personId}",
        "target_id": "${companyId}",
        "properties": {}
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "INVALID_EDGE"

  Scenario: Creating edge with non-existent source entity returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "00000000-0000-0000-0000-000000000000",
        "target_id": "${personId}",
        "properties": {}
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "source"

  Scenario: Creating edge with non-existent target entity returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "${personId}",
        "target_id": "00000000-0000-0000-0000-000000000000",
        "properties": {}
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "target"

  Scenario: Creating edge with invalid enum property value returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "EMPLOYS",
        "source_id": "${companyId}",
        "target_id": "${personId}",
        "properties": {
          "role": "intern"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "role"
    And the response body path "$.errors[0].constraint" should equal "enum"

  Scenario: Creating edge with missing required fields returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS"
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/edges/:id — Get single edge
  # ---------------------------------------------------------------------------

  Scenario: Get edge by ID
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges/${employsEdgeId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${employsEdgeId}"
    And the response body path "$.data.type" should equal "EMPLOYS"
    And the response body path "$.data.source_id" should exist
    And the response body path "$.data.target_id" should exist

  Scenario: Get non-existent edge returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/edges — List edges
  # ---------------------------------------------------------------------------

  Scenario: List all edges in a workspace
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.meta.total" should exist

  Scenario: List edges filtered by type
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "type" to "EMPLOYS"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].type" should equal "EMPLOYS"

  Scenario: List edges with pagination
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | limit  | 5 |
      | offset | 0 |
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200
    And the response body path "$.meta.limit" should equal 5
    And the response body path "$.meta.offset" should equal 0

  Scenario: Soft-deleted edges are excluded from listing by default
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Include soft-deleted edges with query param
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "include_deleted" to "true"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200
    And the response body should be valid JSON

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:workspace_id/edges/:id — Update edge
  # ---------------------------------------------------------------------------

  Scenario: Update edge properties
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/edges/${employsEdgeId}" with body:
      """
      {
        "properties": {
          "role": "part-time",
          "since": "2025-06-01T00:00:00Z"
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.properties.role" should equal "part-time"
    And the response body path "$.data.updated_at" should exist

  Scenario: Updating edge with invalid property returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/edges/${employsEdgeId}" with body:
      """
      {
        "properties": {
          "role": "volunteer"
        }
      }
      """
    Then the response status should be 422
    And the response body path "$.errors[0].field" should equal "role"
    And the response body path "$.errors[0].constraint" should equal "enum"

  Scenario: Updating non-existent edge returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/edges/00000000-0000-0000-0000-000000000000" with body:
      """
      {
        "properties": {"role": "full-time"}
      }
      """
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/workspaces/:workspace_id/edges/:id — Soft-delete edge
  # ---------------------------------------------------------------------------

  Scenario: Soft-delete an edge
    # First create an edge to delete
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "KNOWS",
        "source_id": "${personId}",
        "target_id": "${personId2}",
        "properties": {}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "deleteEdgeId"
    # Soft-delete it
    Given I set bearer token to "${admin-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/edges/${deleteEdgeId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${deleteEdgeId}"
    And the response body path "$.data.deleted_at" should exist

  Scenario: Soft-deleted edge is excluded from normal GET
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges/${deleteEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Deleting non-existent edge returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/edges/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # Guest role: read-only for edges
  # ---------------------------------------------------------------------------

  Scenario: Guest can read edges
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/edges"
    Then the response status should be 200

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

  # ---------------------------------------------------------------------------
  # Cross-workspace isolation for edges
  # ---------------------------------------------------------------------------

  Scenario: Cannot access edge from another workspace
    Given I set bearer token to "${admin-token-ws-002}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/edges/${employsEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"
