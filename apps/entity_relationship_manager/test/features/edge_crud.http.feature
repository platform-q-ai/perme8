@http
Feature: Edge/Relationship CRUD API
  As an API consumer
  I want to create, read, update, and delete edges between entities via the REST API
  So that I can model relationships in my workspace's entity graph

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Setup: create the entities needed by this feature file
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
        "properties": {"full_name": "Edge Test Alice", "email": "edge.alice@example.com"}
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
        "properties": {"full_name": "Edge Test Bob"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "personId2"

  Scenario: Setup - create Company entity (companyId)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities" with body:
      """
      {
        "type": "Company",
        "properties": {"name": "Edge Test Corp"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "companyId"

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:workspace_id/edges — Create edge
  # ---------------------------------------------------------------------------

  Scenario: Create an EMPLOYS edge between Company and Person
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    And the response body path "$.errors[0].message" should contain "Source"

  Scenario: Creating edge with non-existent target entity returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    And the response body path "$.errors[0].message" should contain "Target"

  Scenario: Creating edge with invalid enum property value returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges/${employsEdgeId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${employsEdgeId}"
    And the response body path "$.data.type" should equal "EMPLOYS"
    And the response body path "$.data.source_id" should exist
    And the response body path "$.data.target_id" should exist

  Scenario: Get non-existent edge returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/edges — List edges
  # ---------------------------------------------------------------------------

  Scenario: List all edges in a workspace
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.meta.total" should exist

  Scenario: List edges filtered by type
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set query param "type" to "EMPLOYS"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].type" should equal "EMPLOYS"

  Scenario: List edges with pagination
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set the following query params:
      | limit  | 5 |
      | offset | 0 |
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200
    And the response body path "$.meta.limit" should equal 5
    And the response body path "$.meta.offset" should equal 0

  Scenario: Soft-deleted edges are excluded from listing by default
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Include soft-deleted edges with query param
    Given I set bearer token to "${valid-doc-key-product-team}"
    And I set query param "include_deleted" to "true"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200
    And the response body should be valid JSON

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:workspace_id/edges/:id — Update edge
  # ---------------------------------------------------------------------------

  Scenario: Update edge properties
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/edges/${employsEdgeId}" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/edges/${employsEdgeId}" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/edges/00000000-0000-0000-0000-000000000000" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges" with body:
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
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I DELETE "/api/v1/workspaces/${workspace-id-product-team}/edges/${deleteEdgeId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${deleteEdgeId}"
    And the response body path "$.data.deleted_at" should exist

  Scenario: Soft-deleted edge is excluded from normal GET
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges/${deleteEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Deleting non-existent edge returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I DELETE "/api/v1/workspaces/${workspace-id-product-team}/edges/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # Guest role: read-only for edges
  # ---------------------------------------------------------------------------

  Scenario: Guest can read edges
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/edges"
    Then the response status should be 200

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

  # ---------------------------------------------------------------------------
  # Cross-workspace isolation for edges
  # ---------------------------------------------------------------------------

  Scenario: Cannot access edge from another workspace
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/edges/${employsEdgeId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"
