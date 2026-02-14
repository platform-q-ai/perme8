@http
Feature: Project API Access
  As an API consumer
  I want to create and retrieve projects via the REST API using API keys
  So that I can integrate project management with external systems programmatically

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Project POST Endpoint - Create projects
  # ---------------------------------------------------------------------------

  Scenario: User creates project via API key
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Q1 Launch Via API",
        "description": "Q1 product launch project"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Q1 Launch Via API"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.description" should equal "Q1 product launch project"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And I store response body path "$.data.slug" as "createdProjectSlug"

  Scenario: User creates project with minimal data
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Simple Project"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Simple Project"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: Create project with invalid data
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "description": "Project without name"
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.name" should exist

  Scenario: API key without workspace access cannot create project
    # Assumes: alice@example.com has API key with access to engineering (NOT product-team)
    Given I set bearer token to "${valid-key-engineering-only}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Unauthorized Project",
        "description": "Should not be created"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Guest role API key cannot create project
    # Assumes: guest@example.com has "guest" role in product-team
    # Assumes: API key "${valid-guest-key-product-team}" is owned by guest@example.com
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Should Fail",
        "description": "User doesn't have permission"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Owner role API key can create projects
    # Assumes: alice@example.com has "owner" role in product-team (workspace creator)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Owner Created Project",
        "description": "Created by owner"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Owner Created Project"
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: Member role API key can create projects
    # Assumes: bob@example.com has "member" role in product-team
    # Assumes: API key "${valid-member-key-product-team}" is owned by bob@example.com
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Member Created Project",
        "description": "Created by member"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Member Created Project"
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: Revoked API key cannot create project
    # Assumes: API key was valid but has been revoked
    Given I set bearer token to "${revoked-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Should Fail",
        "description": "Revoked key"
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot create project
    Given I set bearer token to "invalid-key-12345"
    When I POST to "/api/workspaces/product-team/projects" with body:
      """
      {
        "name": "Should Fail",
        "description": "Invalid key"
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  # ---------------------------------------------------------------------------
  # Project GET Endpoint - Retrieve specific project
  # ---------------------------------------------------------------------------

  Scenario: User retrieves project via API key
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Q1 Launch"
    And the response body path "$.data.description" should equal "Q1 product launch plan"
    And the response body path "$.data.slug" should equal "q1-launch"
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: Project response includes associated documents
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    # Assumes: project has at least the seeded document "Launch Plan" with slug "launch-plan"
    # Note: earlier POST scenarios may have also created documents in this project
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Q1 Launch"
    And the response body path "$.data.documents" should exist
    And the response body path "$.data.documents[0].slug" should exist
    And the response body path "$.data.documents[0].title" should exist

  Scenario: API key cannot access project in workspace it doesn't have access to
    # Assumes: API key has access to engineering, NOT product-team
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Project not found returns 404
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/projects/non-existent-project"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Project not found"

  Scenario: Revoked API key cannot retrieve project
    # Assumes: API key was valid but has been revoked
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot retrieve project
    Given I set bearer token to "invalid-key-12345"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Guest role API key can retrieve project
    # Assumes: guest@example.com has "guest" role in product-team
    # Assumes: API key "${valid-guest-key-product-team}" is owned by guest@example.com
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I GET "/api/workspaces/product-team/projects/q1-launch"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.name" should equal "Q1 Launch"
    And the response body path "$.data.slug" should equal "q1-launch"
