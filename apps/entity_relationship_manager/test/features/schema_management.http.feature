@http
Feature: Schema Management API
  As a workspace administrator
  I want to define and manage entity type schemas via the REST API
  So that my team can create structured graph data conforming to our domain model

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:workspace_id/schema — Define a new schema
  # ---------------------------------------------------------------------------

  Scenario: Admin defines a workspace schema with entity and edge types
    # Assumes: admin-token belongs to a user with owner/admin role in workspace ws-001
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
          {
            "name": "KNOWS",
            "properties": []
          }
        ]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types" should have 2 items
    And the response body path "$.data.entity_types[0].name" should equal "Person"
    And the response body path "$.data.entity_types[1].name" should equal "Company"
    And the response body path "$.data.edge_types" should have 2 items
    And the response body path "$.data.edge_types[0].name" should equal "EMPLOYS"
    And the response body path "$.data.edge_types[1].name" should equal "KNOWS"
    And the response body path "$.data.version" should exist
    And the response body path "$.data.id" should exist

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/schema — Read schema
  # ---------------------------------------------------------------------------

  Scenario: Admin retrieves the current workspace schema
    # Assumes: workspace ws-001 already has a schema defined
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/schema"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types" should exist
    And the response body path "$.data.edge_types" should exist
    And the response body path "$.data.version" should exist
    And the response body path "$.data.workspace_id" should equal "${workspace-id-product-team}"

  Scenario: Member can read the workspace schema
    # Assumes: member-token belongs to a user with member role in workspace ws-001
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/schema"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types" should exist

  Scenario: Guest can read the workspace schema
    # Assumes: guest-token belongs to a user with guest role in workspace ws-001
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/schema"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types" should exist

  Scenario: Reading schema for workspace with no schema returns 404
    # Assumes: workspace ws-empty has no schema defined
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/v1/workspaces/${workspace-id-engineering}/schema"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "schema_not_found"

  # ---------------------------------------------------------------------------
  # PUT /api/v1/workspaces/:workspace_id/schema — Update existing schema
  # ---------------------------------------------------------------------------

  Scenario: Admin adds a new entity type to an existing schema
    # Assumes: workspace ws-001 has a schema with Person and Company entity types
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/v1/workspaces/${workspace-id-product-team}/schema"
    Then the response status should be 200
    And I store response body path "$.data.version" as "currentVersion"
    # Now update the schema with an additional entity type
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "version": ${currentVersion},
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
          },
          {
            "name": "Service",
            "properties": [
              {"name": "name", "type": "string", "required": true},
              {"name": "status", "type": "string", "required": true, "constraints": {"enum": ["active", "deprecated", "planned"]}}
            ]
          }
        ],
        "edge_types": [
          {"name": "EMPLOYS", "properties": []},
          {"name": "KNOWS", "properties": []},
          {"name": "DEPENDS_ON", "properties": [{"name": "criticality", "type": "string", "required": false}]}
        ]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types" should have 3 items
    And the response body path "$.data.edge_types" should have 3 items
    And the response body path "$.data.entity_types[2].name" should equal "Service"
    And the response body path "$.data.edge_types[2].name" should equal "DEPENDS_ON"

  Scenario: Schema update with stale version causes conflict
    # Assumes: workspace ws-001 has a schema at version > 1
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
    And the response body path "$.message" should contain "concurrent"

  # ---------------------------------------------------------------------------
  # Schema validation errors
  # ---------------------------------------------------------------------------

  Scenario: Schema with invalid property type is rejected
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {
            "name": "BadType",
            "properties": [
              {"name": "data", "type": "array", "required": false}
            ]
          }
        ],
        "edge_types": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    And the response body path "$.errors[0].message" should contain "type"

  Scenario: Schema with duplicate entity type names is rejected
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "Person", "properties": [{"name": "name", "type": "string", "required": true}]},
          {"name": "Person", "properties": [{"name": "label", "type": "string", "required": true}]}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "duplicate"

  Scenario: Schema with empty entity type name is rejected
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "", "properties": []}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist

  Scenario: Schema with invalid entity type name characters is rejected
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "DROP TABLE;", "properties": []}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors[0].message" should contain "name"

  Scenario: Schema with missing required fields is rejected
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist

  # ---------------------------------------------------------------------------
  # Authorization: only admin/owner can modify schema
  # ---------------------------------------------------------------------------

  Scenario: Member cannot update workspace schema
    Given I set bearer token to "${valid-member-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "Hack", "properties": []}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot update workspace schema
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {"name": "Hack", "properties": []}
        ],
        "edge_types": []
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "forbidden"

  # ---------------------------------------------------------------------------
  # Property constraint validation
  # ---------------------------------------------------------------------------

  Scenario: Schema with valid property constraints is accepted
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/schema" with body:
      """
      {
        "entity_types": [
          {
            "name": "Product",
            "properties": [
              {"name": "name", "type": "string", "required": true, "constraints": {"min_length": 1, "max_length": 500}},
              {"name": "price", "type": "float", "required": true, "constraints": {"min": 0.0}},
              {"name": "in_stock", "type": "boolean", "required": true},
              {"name": "released_at", "type": "datetime", "required": false}
            ]
          }
        ],
        "edge_types": [
          {
            "name": "CONTAINS",
            "properties": [
              {"name": "quantity", "type": "integer", "required": true, "constraints": {"min": 1}}
            ]
          }
        ]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.entity_types[0].properties" should have 4 items
    And the response body path "$.data.edge_types[0].properties" should have 1 items
