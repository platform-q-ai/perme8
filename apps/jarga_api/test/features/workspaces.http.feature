@http
Feature: Workspace API Access
  As an API consumer
  I want to access workspace data via the REST API using API keys
  So that I can retrieve workspace information including documents and projects

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Workspaces LIST Endpoint - List all accessible workspaces
  # ---------------------------------------------------------------------------

  Scenario: API key with multi-workspace access lists all accessible workspaces
    # Assumes: alice@example.com has API key with access to product-team AND engineering
    Given I set bearer token to "${valid-multi-workspace-key}"
    When I GET "/api/workspaces"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 2 items
    And the response body path "$.data[0].name" should exist
    And the response body path "$.data[0].slug" should exist
    And the response body path "$.data[1].name" should exist
    And the response body path "$.data[1].slug" should exist

  Scenario: API key with single workspace access lists one workspace
    # Assumes: alice@example.com has API key with access to product-team only
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 1 items
    And the response body path "$.data[0].slug" should equal "product-team"

  Scenario: API key with no workspace access returns empty list
    # Assumes: alice@example.com has API key with no workspace access
    Given I set bearer token to "${valid-no-access-key}"
    When I GET "/api/workspaces"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 0 items

  Scenario: Workspace list includes basic information for each workspace
    # Assumes: alice@example.com has API key with access to product-team AND engineering
    Given I set bearer token to "${valid-multi-workspace-key}"
    When I GET "/api/workspaces"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].name" should exist
    And the response body path "$.data[0].slug" should exist
    And the response body path "$.data[1].name" should exist
    And the response body path "$.data[1].slug" should exist

  Scenario: Revoked API key cannot list workspaces
    # Assumes: alice@example.com has a revoked API key
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/workspaces"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot list workspaces
    Given I set bearer token to "invalid-key-12345"
    When I GET "/api/workspaces"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Workspace list does not include full documents and projects
    # Assumes: workspace product-team has documents and projects in seed data
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].documents" should not exist
    And the response body path "$.data[0].projects" should not exist

  # ---------------------------------------------------------------------------
  # Workspace GET Endpoint - Retrieve workspace with documents and projects
  # ---------------------------------------------------------------------------

  Scenario: User retrieves workspace details including documents and projects
    # Assumes: workspace product-team has seed documents and project (Q1 Launch)
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Product Team"
    And the response body path "$.data.slug" should equal "product-team"
    And the response body path "$.data.documents" should exist
    And the response body path "$.data.projects" should exist

  Scenario: Workspace response includes document slugs
    # Assumes: workspace product-team has document "Product Spec" with slug "product-spec"
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.documents[0].slug" should exist
    And the response body path "$.data.documents[0].title" should exist

  Scenario: Workspace response includes project slugs
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.projects[0].slug" should exist
    And the response body path "$.data.projects[0].name" should exist

  Scenario: API key without workspace access cannot access workspace
    # Assumes: alice@example.com has API key with access to engineering (NOT product-team)
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Revoked API key cannot access workspace
    # Assumes: alice@example.com has a revoked API key
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot access workspace
    Given I set bearer token to "invalid-key-12345"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Workspace not found returns 403 when API key lacks access
    # The API key only has access to product-team, so accessing a non-existent
    # workspace is rejected at the authorization layer before lookup occurs
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/non-existent-workspace"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Guest role API key can access workspace
    # Assumes: guest@example.com has "guest" role in product-team
    # Assumes: API key "${valid-guest-key-product-team}" is owned by guest@example.com
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/workspaces/product-team"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Product Team"
    And the response body path "$.data.slug" should equal "product-team"
