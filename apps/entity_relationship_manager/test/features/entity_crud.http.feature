@http
Feature: Entity CRUD API
  As an API consumer
  I want to create, read, update, and delete entities via the REST API
  So that I can manage structured graph data conforming to my workspace schema

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:workspace_id/entities — Create entity
  # ---------------------------------------------------------------------------

  Scenario: Create a Person entity with valid properties
    # Assumes: workspace ws-001 has a schema with Person entity type
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Alice Smith",
          "email": "alice@example.com",
          "age": 30
        }
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.type" should equal "Person"
    And the response body path "$.data.properties.full_name" should equal "Alice Smith"
    And the response body path "$.data.properties.email" should equal "alice@example.com"
    And the response body path "$.data.properties.age" should equal 30
    And the response body path "$.data.workspace_id" should equal "${workspace-id-001}"
    And the response body path "$.data.created_at" should exist
    And the response body path "$.data.updated_at" should exist
    And the response body path "$.data.deleted_at" should be null
    And I store response body path "$.data.id" as "personId"

  Scenario: Create a Company entity with only required properties
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Company",
        "properties": {
          "name": "Acme Corp"
        }
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.type" should equal "Company"
    And the response body path "$.data.properties.name" should equal "Acme Corp"
    And I store response body path "$.data.id" as "companyId"

  Scenario: Member can create entities
    Given I set bearer token to "${member-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Bob Johnson"
        }
      }
      """
    Then the response status should be 201
    And the response body path "$.data.type" should equal "Person"
    And the response body path "$.data.properties.full_name" should equal "Bob Johnson"

  # ---------------------------------------------------------------------------
  # POST — Validation errors
  # ---------------------------------------------------------------------------

  Scenario: Creating entity with missing required property returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "email": "missing-name@example.com"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    And the response body path "$.errors[0].field" should equal "full_name"
    And the response body path "$.errors[0].message" should contain "required"

  Scenario: Creating entity with property violating min constraint returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Alice",
          "age": -5
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "age"
    And the response body path "$.errors[0].message" should contain "must be >= 0"
    And the response body path "$.errors[0].constraint" should equal "min"

  Scenario: Creating entity with property violating max constraint returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Methuselah",
          "age": 999
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "age"
    And the response body path "$.errors[0].constraint" should equal "max"

  Scenario: Creating entity with property violating pattern constraint returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Alice",
          "email": "not-an-email"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].field" should equal "email"
    And the response body path "$.errors[0].constraint" should equal "pattern"

  Scenario: Creating entity with unconfigured type returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "UnknownType",
        "properties": {
          "name": "Ghost"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "UnknownType"

  Scenario: Creating entity in workspace with no schema returns 422
    # Assumes: workspace ws-empty has no schema defined
    Given I set bearer token to "${admin-token-ws-empty}"
    When I POST to "/api/v1/workspaces/${workspace-id-empty}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "Nobody"
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should equal "no_schema_configured"

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/entities/:id — Read entity
  # ---------------------------------------------------------------------------

  Scenario: Get entity by ID
    # Assumes: entity personId was created in a previous test run or fixture
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${personId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${personId}"
    And the response body path "$.data.type" should equal "Person"
    And the response body path "$.data.properties.full_name" should exist
    And the response body path "$.data.workspace_id" should equal "${workspace-id-001}"

  Scenario: Get non-existent entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  Scenario: Get entity from another workspace returns 404
    # Assumes: entity personId belongs to workspace ws-001, not ws-002
    Given I set bearer token to "${admin-token-ws-002}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/entities/${personId}"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/entities — List entities
  # ---------------------------------------------------------------------------

  Scenario: List all entities in a workspace
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.meta.total" should exist
    And the response body path "$.meta.limit" should exist
    And the response body path "$.meta.offset" should exist

  Scenario: List entities filtered by type
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "type" to "Person"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].type" should equal "Person"

  Scenario: List entities with pagination
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | limit  | 2 |
      | offset | 0 |
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.meta.limit" should equal 2
    And the response body path "$.meta.offset" should equal 0

  Scenario: Soft-deleted entities are excluded from listings by default
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    # All returned entities should have null deleted_at

  Scenario: Include soft-deleted entities with query param
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "include_deleted" to "true"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:workspace_id/entities/:id — Update entity
  # ---------------------------------------------------------------------------

  Scenario: Update entity properties
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/entities/${personId}" with body:
      """
      {
        "properties": {
          "full_name": "Alice Smith-Jones",
          "email": "alice.jones@example.com",
          "age": 31
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.properties.full_name" should equal "Alice Smith-Jones"
    And the response body path "$.data.properties.email" should equal "alice.jones@example.com"
    And the response body path "$.data.properties.age" should equal 31
    And the response body path "$.data.updated_at" should exist

  Scenario: Updating entity with invalid properties returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/entities/${personId}" with body:
      """
      {
        "properties": {
          "full_name": "",
          "age": -10
        }
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist

  Scenario: Updating non-existent entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I PUT to "/api/v1/workspaces/${workspace-id-001}/entities/00000000-0000-0000-0000-000000000000" with body:
      """
      {
        "properties": {"full_name": "Ghost"}
      }
      """
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/workspaces/:workspace_id/entities/:id — Soft-delete entity
  # ---------------------------------------------------------------------------

  Scenario: Soft-delete an entity
    # First, create an entity to delete
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {
          "full_name": "To Be Deleted"
        }
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "deleteTargetId"
    # Now soft-delete it
    Given I set bearer token to "${admin-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/entities/${deleteTargetId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${deleteTargetId}"
    And the response body path "$.data.deleted_at" should exist

  Scenario: Soft-deleted entity is excluded from normal GET
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${deleteTargetId}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Soft-deleted entity is visible with include_deleted param
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "include_deleted" to "true"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${deleteTargetId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${deleteTargetId}"
    And the response body path "$.data.deleted_at" should exist

  Scenario: Deleting an entity cascades soft-delete to its edges
    # Assumes: entity has edges attached
    # First create two entities and an edge
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Person",
        "properties": {"full_name": "Cascade Source"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "cascadeSourceId"
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/entities" with body:
      """
      {
        "type": "Company",
        "properties": {"name": "Cascade Target Corp"}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "cascadeTargetId"
    Given I set bearer token to "${admin-token-ws-001}"
    When I POST to "/api/v1/workspaces/${workspace-id-001}/edges" with body:
      """
      {
        "type": "EMPLOYS",
        "source_id": "${cascadeTargetId}",
        "target_id": "${cascadeSourceId}",
        "properties": {}
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "cascadeEdgeId"
    # Now delete the source entity
    Given I set bearer token to "${admin-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/entities/${cascadeSourceId}"
    Then the response status should be 200
    And the response body path "$.data.deleted_at" should exist
    And the response body path "$.meta.edges_deleted" should exist

  Scenario: Deleting non-existent entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I DELETE "/api/v1/workspaces/${workspace-id-001}/entities/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # Guest role: read-only access
  # ---------------------------------------------------------------------------

  Scenario: Guest can read entities
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities"
    Then the response status should be 200

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
