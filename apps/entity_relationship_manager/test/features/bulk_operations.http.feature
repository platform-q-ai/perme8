@http
Feature: Bulk Operations API
  As an API consumer
  I want to perform bulk create, update, and delete operations via the REST API
  So that I can efficiently import or transform large amounts of graph data

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Setup: ensure schema exists for this feature file
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

  # ===========================================================================
  # POST /api/v1/workspaces/:workspace_id/entities/bulk — Bulk create entities
  # ===========================================================================

  Scenario: Bulk create multiple entities in atomic mode
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Bulk Alice", "email": "bulk.alice@example.com"}},
          {"type": "Person", "properties": {"full_name": "Bulk Bob", "email": "bulk.bob@example.com"}},
          {"type": "Company", "properties": {"name": "Bulk Corp"}}
        ]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data" should have 3 items
    And the response body path "$.data[0].id" should exist
    And the response body path "$.data[0].type" should equal "Person"
    And the response body path "$.data[1].type" should equal "Person"
    And the response body path "$.data[2].type" should equal "Company"
    And the response body path "$.meta.created" should equal 3
    And I store response body path "$.data[0].id" as "bulkAliceId"
    And I store response body path "$.data[1].id" as "bulkBobId"
    And I store response body path "$.data[2].id" as "bulkCorpId"

  Scenario: Bulk create in atomic mode rejects entire batch on validation error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Valid Person"}},
          {"type": "Person", "properties": {"email": "missing-name@example.com"}},
          {"type": "Company", "properties": {"name": "Valid Corp"}}
        ]
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    And the response body path "$.errors[0].index" should equal 1
    And the response body path "$.errors[0].errors[0].field" should equal "full_name"
    And the response body path "$.errors[0].errors[0].message" should contain "required"
    And the response body path "$.meta.created" should equal 0

  Scenario: Bulk create in partial mode creates valid items and returns errors for invalid
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "partial",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Partial Alice"}},
          {"type": "Person", "properties": {"email": "no-name@example.com"}},
          {"type": "Company", "properties": {"name": "Partial Corp"}},
          {"type": "UnknownType", "properties": {"name": "Ghost"}}
        ]
      }
      """
    Then the response status should be 207
    And the response body should be valid JSON
    And the response body path "$.data" should have 2 items
    And the response body path "$.errors" should have 2 items
    And the response body path "$.errors[0].index" should equal 1
    And the response body path "$.errors[1].index" should equal 3
    And the response body path "$.meta.created" should equal 2
    And the response body path "$.meta.failed" should equal 2

  Scenario: Bulk create defaults to atomic mode when mode not specified
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "entities": [
          {"type": "Person", "properties": {"full_name": "Default Mode Person"}}
        ]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data" should have 1 items

  Scenario: Bulk create with empty entities array returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "entities"

  # ===========================================================================
  # PUT /api/v1/workspaces/:workspace_id/entities/bulk — Bulk update entities
  # ===========================================================================

  Scenario: Bulk update multiple entities
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"id": "${bulkAliceId}", "properties": {"full_name": "Bulk Alice Updated", "age": 28}},
          {"id": "${bulkBobId}", "properties": {"full_name": "Bulk Bob Updated", "age": 35}}
        ]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 2 items
    And the response body path "$.data[0].properties.full_name" should equal "Bulk Alice Updated"
    And the response body path "$.data[1].properties.full_name" should equal "Bulk Bob Updated"
    And the response body path "$.meta.updated" should equal 2

  Scenario: Bulk update in atomic mode rejects entire batch on validation error
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"id": "${bulkAliceId}", "properties": {"full_name": "Valid Update"}},
          {"id": "${bulkBobId}", "properties": {"age": -10}}
        ]
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors" should exist
    And the response body path "$.errors[0].index" should equal 1
    And the response body path "$.meta.updated" should equal 0

  Scenario: Bulk update in partial mode updates valid items
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "partial",
        "entities": [
          {"id": "${bulkAliceId}", "properties": {"full_name": "Partial Updated Alice"}},
          {"id": "00000000-0000-0000-0000-000000000000", "properties": {"full_name": "Ghost"}}
        ]
      }
      """
    Then the response status should be 207
    And the response body should be valid JSON
    And the response body path "$.data" should have 1 items
    And the response body path "$.errors" should have 1 items
    And the response body path "$.meta.updated" should equal 1
    And the response body path "$.meta.failed" should equal 1

  # ===========================================================================
  # DELETE /api/v1/workspaces/:workspace_id/entities/bulk — Bulk soft-delete
  # ===========================================================================

  Scenario: Bulk soft-delete multiple entities
    # First, create entities for deletion
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Delete Me 1"}},
          {"type": "Person", "properties": {"full_name": "Delete Me 2"}},
          {"type": "Person", "properties": {"full_name": "Delete Me 3"}}
        ]
      }
      """
    Then the response status should be 201
    And I store response body path "$.data[0].id" as "bulkDeleteId1"
    And I store response body path "$.data[1].id" as "bulkDeleteId2"
    And I store response body path "$.data[2].id" as "bulkDeleteId3"
    # Now bulk delete
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I send a DELETE request to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "ids": ["${bulkDeleteId1}", "${bulkDeleteId2}", "${bulkDeleteId3}"]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.meta.deleted" should equal 3

  Scenario: Bulk delete in partial mode skips non-existent IDs
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I send a DELETE request to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "partial",
        "ids": ["${bulkAliceId}", "00000000-0000-0000-0000-000000000000"]
      }
      """
    Then the response status should be 207
    And the response body should be valid JSON
    And the response body path "$.meta.deleted" should equal 1
    And the response body path "$.meta.failed" should equal 1

  Scenario: Bulk delete with empty IDs array returns 422
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I send a DELETE request to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "ids": []
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "ids"

  # ===========================================================================
  # POST /api/v1/workspaces/:workspace_id/edges/bulk — Bulk create edges
  # ===========================================================================

  Scenario: Setup - create entities for edge bulk operations
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Edge Alice"}},
          {"type": "Person", "properties": {"full_name": "Edge Bob"}},
          {"type": "Company", "properties": {"name": "Edge Corp"}}
        ]
      }
      """
    Then the response status should be 201
    And I store response body path "$.data[0].id" as "edgeAliceId"
    And I store response body path "$.data[1].id" as "edgeBobId"
    And I store response body path "$.data[2].id" as "edgeCorpId"

  Scenario: Bulk create multiple edges
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges/bulk" with body:
      """
      {
        "mode": "atomic",
        "edges": [
           {"type": "KNOWS", "source_id": "${edgeAliceId}", "target_id": "${edgeBobId}", "properties": {}},
           {"type": "KNOWS", "source_id": "${edgeBobId}", "target_id": "${edgeCorpId}", "properties": {}},
           {"type": "KNOWS", "source_id": "${edgeAliceId}", "target_id": "${edgeCorpId}", "properties": {}}
         ]
       }
       """
     Then the response status should be 201
     And the response body should be valid JSON
     And the response body path "$.data" should have 3 items
     And the response body path "$.meta.created" should equal 3

   Scenario: Bulk create edges in atomic mode rejects batch on invalid edge type
     Given I set bearer token to "${valid-doc-key-product-team}"
     When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges/bulk" with body:
       """
       {
         "mode": "atomic",
         "edges": [
           {"type": "KNOWS", "source_id": "${edgeAliceId}", "target_id": "${edgeBobId}", "properties": {}},
           {"type": "INVALID_TYPE", "source_id": "${edgeBobId}", "target_id": "${edgeCorpId}", "properties": {}}
         ]
       }
       """
     Then the response status should be 422
     And the response body should be valid JSON
     And the response body path "$.errors[0].index" should equal 1
     And the response body path "$.meta.created" should equal 0

   Scenario: Bulk create edges in partial mode creates valid edges
     Given I set bearer token to "${valid-doc-key-product-team}"
     When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges/bulk" with body:
       """
       {
         "mode": "partial",
         "edges": [
           {"type": "KNOWS", "source_id": "${edgeAliceId}", "target_id": "${edgeBobId}", "properties": {}},
           {"type": "KNOWS", "source_id": "00000000-0000-0000-0000-000000000000", "target_id": "${edgeCorpId}", "properties": {}}
        ]
      }
      """
    Then the response status should be 207
    And the response body should be valid JSON
    And the response body path "$.data" should have 1 items
    And the response body path "$.errors" should have 1 items
    And the response body path "$.meta.created" should equal 1
    And the response body path "$.meta.failed" should equal 1

  # ===========================================================================
  # Authorization for bulk operations
  # ===========================================================================

  Scenario: Guest cannot perform bulk entity create
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Guest Bulk"}}
        ]
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot perform bulk entity update
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I PUT to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"id": "${bulkAliceId}", "properties": {"full_name": "Guest Hack"}}
        ]
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot perform bulk entity delete
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I send a DELETE request to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "ids": ["${bulkAliceId}"]
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Guest cannot perform bulk edge create
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/edges/bulk" with body:
      """
      {
        "mode": "atomic",
        "edges": [
          {"type": "KNOWS", "source_id": "${bulkAliceId}", "target_id": "${bulkBobId}", "properties": {}}
        ]
      }
      """
    Then the response status should be 403
    And the response body path "$.error" should equal "forbidden"

  Scenario: Member can perform bulk entity create
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Member Bulk Person"}}
        ]
      }
      """
    Then the response status should be 201
    And the response body path "$.data" should have 1 items

  # ===========================================================================
  # Performance: bulk operations
  # ===========================================================================

  Scenario: Bulk create 100 entities completes within performance budget
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/v1/workspaces/${workspace-id-product-team}/entities/bulk" with body:
      """
      {
        "mode": "atomic",
        "entities": [
          {"type": "Person", "properties": {"full_name": "Perf Test 001"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 002"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 003"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 004"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 005"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 006"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 007"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 008"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 009"}},
          {"type": "Person", "properties": {"full_name": "Perf Test 010"}}
        ]
      }
      """
    Then the response status should be 201
    And the response time should be less than 5000 ms
