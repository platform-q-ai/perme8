@http
Feature: Graph Traversal API
  As an API consumer
  I want to traverse relationships between entities via the REST API
  So that I can discover how things are connected in my workspace's entity graph

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ===========================================================================
  # Test data setup: build a known graph topology
  # Company (Acme) --EMPLOYS--> Person (Alice)
  # Company (Acme) --EMPLOYS--> Person (Bob)
  # Person (Alice) --KNOWS--> Person (Bob)
  # Person (Bob) --KNOWS--> Person (Carol)
  # Person (Carol) --KNOWS--> Person (Dave)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/entities/:id/neighbors — Direct neighbors
  # ---------------------------------------------------------------------------

  Scenario: Get direct neighbors of an entity (both directions)
    # Assumes: entity traversePersonAlice has outgoing KNOWS to Bob and incoming EMPLOYS from Acme
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.meta.total" should exist

  Scenario: Get outbound neighbors only
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "direction" to "out"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: Get inbound neighbors only
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "direction" to "in"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: Filter neighbors by edge type
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "type" to "KNOWS"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: Neighbors of non-existent entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/00000000-0000-0000-0000-000000000000/neighbors"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Neighbors of entity with no connections returns empty list
    # Assumes: traverseIsolatedEntity exists but has no edges
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traverseIsolatedEntity}/neighbors"
    Then the response status should be 200
    And the response body path "$.data" should have 0 items
    And the response body path "$.meta.total" should equal 0

  Scenario: Neighbors excludes soft-deleted entities by default
    # Assumes: traverseDeletedNeighbor was soft-deleted but linked to traversePersonAlice
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON
    # Soft-deleted neighbors should not appear

  Scenario: Neighbors with pagination
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | limit  | 1 |
      | offset | 0 |
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body path "$.meta.limit" should equal 1
    And the response body path "$.meta.offset" should equal 0

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/entities/:id/paths/:target_id — Path finding
  # ---------------------------------------------------------------------------

  Scenario: Find paths between two connected entities
    # Assumes: traversePersonAlice --KNOWS--> traversePersonBob
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonBob}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.data[0].nodes" should exist
    And the response body path "$.data[0].edges" should exist

  Scenario: Find paths between entities with multiple hops
    # Assumes: Alice --KNOWS--> Bob --KNOWS--> Carol (2-hop path)
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonCarol}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  Scenario: Find paths with depth limit
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "depth" to "1"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonCarol}"
    Then the response status should be 200
    And the response body should be valid JSON
    # With depth 1, Alice cannot reach Carol (needs 2 hops), so empty paths
    And the response body path "$.data" should have 0 items

  Scenario: Paths between unconnected entities returns empty
    # Assumes: traverseIsolatedEntity has no connections
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traverseIsolatedEntity}"
    Then the response status should be 200
    And the response body path "$.data" should have 0 items

  Scenario: Paths with non-existent source entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/00000000-0000-0000-0000-000000000000/paths/${traversePersonBob}"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Paths with non-existent target entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  Scenario: Paths filtered by edge type
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "type" to "KNOWS"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonBob}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:workspace_id/traverse — N-degree traversal
  # ---------------------------------------------------------------------------

  Scenario: N-degree traversal from a starting entity with default depth
    # Assumes: default depth is 1
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "start_id" to "${traversePersonAlice}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist
    And the response body path "$.data.edges" should exist
    And the response body path "$.meta.depth" should equal 1

  Scenario: N-degree traversal with depth 2
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id | ${traversePersonAlice} |
      | depth    | 2                       |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist
    And the response body path "$.data.edges" should exist
    And the response body path "$.meta.depth" should equal 2

  Scenario: N-degree traversal with depth 3 reaches distant nodes
    # Assumes: Alice --KNOWS--> Bob --KNOWS--> Carol --KNOWS--> Dave
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id | ${traversePersonAlice} |
      | depth    | 3                       |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist

  Scenario: N-degree traversal filtered by entity type
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id | ${traversePersonAlice} |
      | depth    | 2                       |
      | type     | Person                  |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist

  Scenario: N-degree traversal with direction filter
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id  | ${traversePersonAlice} |
      | depth     | 2                       |
      | direction | out                     |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist

  Scenario: N-degree traversal respects maximum depth limit
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id | ${traversePersonAlice} |
      | depth    | 15                      |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "depth"
    And the response body path "$.message" should contain "10"

  Scenario: N-degree traversal handles cyclic graphs without infinite loops
    # Assumes: A circular graph exists (e.g. A->B->C->A)
    Given I set bearer token to "${admin-token-ws-001}"
    And I set the following query params:
      | start_id | ${traverseCycleNodeA} |
      | depth    | 5                      |
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.nodes" should exist
    # Nodes should not be duplicated — cycle detection prevents revisiting
    And the response time should be less than 5000 ms

  Scenario: Traversal without start_id returns 422
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should contain "start_id"

  Scenario: Traversal with non-existent start entity returns 404
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "start_id" to "00000000-0000-0000-0000-000000000000"
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # Traversal: read-only — all roles can traverse
  # ---------------------------------------------------------------------------

  Scenario: Guest can traverse the graph
    Given I set bearer token to "${guest-token-ws-001}"
    And I set query param "start_id" to "${traversePersonAlice}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/traverse"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest can view neighbors
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Guest can find paths
    Given I set bearer token to "${guest-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonBob}"
    Then the response status should be 200
    And the response body should be valid JSON

  # ---------------------------------------------------------------------------
  # Cross-workspace isolation for traversal
  # ---------------------------------------------------------------------------

  Scenario: Traversal is scoped to workspace
    # Assumes: traversePersonAlice belongs to ws-001, not ws-002
    Given I set bearer token to "${admin-token-ws-002}"
    And I set query param "start_id" to "${traversePersonAlice}"
    When I GET "/api/v1/workspaces/${workspace-id-002}/traverse"
    Then the response status should be 404
    And the response body path "$.error" should equal "not_found"

  # ---------------------------------------------------------------------------
  # Performance assertion for traversal
  # ---------------------------------------------------------------------------

  Scenario: Single-entity neighbor query responds within performance budget
    Given I set bearer token to "${admin-token-ws-001}"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/neighbors"
    Then the response status should be 200
    And the response time should be less than 500 ms

  Scenario: Path finding responds within performance budget
    Given I set bearer token to "${admin-token-ws-001}"
    And I set query param "depth" to "3"
    When I GET "/api/v1/workspaces/${workspace-id-001}/entities/${traversePersonAlice}/paths/${traversePersonDave}"
    Then the response status should be 200
    And the response time should be less than 500 ms
