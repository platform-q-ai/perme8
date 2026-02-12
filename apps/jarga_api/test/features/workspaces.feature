Feature: Workspace API Access
  As a developer
  I want to access workspace data via REST API using API keys
  So that I can retrieve workspace information including documents and projects

  Background:
    Given the following users exist:
      | Email               | Name        |
      | alice@example.com   | Alice Smith |
      | bob@example.com     | Bob Johnson |
    And the following workspaces exist:
      | Name            | Slug            | Owner             |
      | Product Team    | product-team    | alice@example.com |
      | Engineering     | engineering     | alice@example.com |
      | Marketing       | marketing       | bob@example.com   |
    And "alice@example.com" is a member of workspace "product-team"
    And "alice@example.com" is a member of workspace "engineering"
    And "bob@example.com" is a member of workspace "marketing"

  # Workspaces LIST Endpoint - List all accessible workspaces
  Scenario: User lists all workspaces available to API key
    Given I am logged in as "alice@example.com"
    And I have an API key "multi-workspace-key" with access to "product-team,engineering"
    When I make a GET request to "/api/workspaces" with API key "multi-workspace-key"
    Then the response status should be 200
    And the response should include 2 workspaces
    And the response should include workspace "product-team" with slug
    And the response should include workspace "engineering" with slug
    And the response should not include workspace "marketing"

  Scenario: API key with single workspace access lists one workspace
    Given I am logged in as "alice@example.com"
    And I have an API key "single-workspace-key" with access to "product-team"
    When I make a GET request to "/api/workspaces" with API key "single-workspace-key"
    Then the response status should be 200
    And the response should include 1 workspace
    And the response should include workspace "product-team" with slug
    And the response should not include workspace "engineering"
    And the response should not include workspace "marketing"

  Scenario: API key with no workspace access returns empty list
    Given I am logged in as "alice@example.com"
    And I have an API key "no-access-key" with no workspace access
    When I make a GET request to "/api/workspaces" with API key "no-access-key"
    Then the response status should be 200
    And the response should include 0 workspaces

  Scenario: Workspace list includes basic information for each workspace
    Given I am logged in as "alice@example.com"
    And I have an API key "multi-workspace-key" with access to "product-team,engineering"
    When I make a GET request to "/api/workspaces" with API key "multi-workspace-key"
    Then the response status should be 200
    And each workspace in the response should have a "name" field
    And each workspace in the response should have a "slug" field

  Scenario: Revoked API key cannot list workspaces
    Given I am logged in as "alice@example.com"
    And I have a revoked API key "revoked-key" with access to "product-team"
    When I make a GET request to "/api/workspaces" with API key "revoked-key"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Invalid API key cannot list workspaces
    When I make a GET request to "/api/workspaces" with API key "invalid-key-12345"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Workspace list does not include full documents and projects
    Given I am logged in as "alice@example.com"
    And I have an API key "workspace-key" with access to "product-team"
    And workspace "product-team" has the following documents:
      | Title           | Content         | Owner             |
      | Product Spec    | Specifications  | alice@example.com |
    And workspace "product-team" has the following projects:
      | Name            | Description           |
      | Q1 Launch       | Q1 product launch     |
    When I make a GET request to "/api/workspaces" with API key "workspace-key"
    Then the response status should be 200
    And the response should not include document details
    And the response should not include project details

  # Workspace GET Endpoint - Lists documents and projects
  Scenario: User accesses workspace via API key
    Given I am logged in as "alice@example.com"
    And I have an API key "workspace-key" with access to "product-team"
    And workspace "product-team" has the following documents:
      | Title           | Content         | Owner             |
      | Product Spec    | Specifications  | alice@example.com |
      | Design Doc      | Design details  | alice@example.com |
    And workspace "product-team" has the following projects:
      | Name            | Description           |
      | Q1 Launch       | Q1 product launch     |
      | User Research   | Research project      |
    When I make a GET request to "/api/workspaces/product-team" with API key "workspace-key"
    Then the response status should be 200
    And the response should include workspace "product-team" details
    And the response should include workspace slug "product-team"
    And the response should include 2 documents
    And the response should include document "Product Spec" with slug
    And the response should include document "Design Doc" with slug
    And the response should include 2 projects
    And the response should include project "Q1 Launch" with slug
    And the response should include project "User Research" with slug

  Scenario: API key without workspace access cannot access workspace
    Given I am logged in as "alice@example.com"
    And I have an API key "limited-key" with access to "engineering"
    And workspace "product-team" exists
    When I make a GET request to "/api/workspaces/product-team" with API key "limited-key"
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: Revoked API key cannot access workspace
    Given I am logged in as "alice@example.com"
    And I have a revoked API key "revoked-key" with access to "product-team"
    When I make a GET request to "/api/workspaces/product-team" with API key "revoked-key"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Invalid API key is rejected
    When I make a GET request to "/api/workspaces/product-team" with API key "invalid-key-12345"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Workspace not found returns 404
    Given I am logged in as "alice@example.com"
    And I have an API key "missing-workspace-key" with access to "non-existent-workspace"
    When I make a GET request to "/api/workspaces/non-existent-workspace" with API key "missing-workspace-key"
    Then the response status should be 404
    And the response should include error "Workspace not found"

  Scenario: API key respects user role in workspace
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "guest" role in workspace "product-team"
    And I have an API key "guest-key" with access to "product-team"
    When I make a GET request to "/api/workspaces/product-team" with API key "guest-key"
    Then the response status should be 200
    And the response should include workspace "product-team" details
    And the response should include workspace slug "product-team"

  Scenario: Workspace response includes document and project IDs for subsequent requests
    Given I am logged in as "alice@example.com"
    And I have an API key "workspace-key" with access to "product-team"
    And workspace "product-team" has the following documents:
      | Title           | Content         | Owner             |
      | Product Spec    | Specifications  | alice@example.com |
    And workspace "product-team" has the following projects:
      | Name            | Description           |
      | Q1 Launch       | Q1 product launch     |
    When I make a GET request to "/api/workspaces/product-team" with API key "workspace-key"
    Then the response status should be 200
    And each document in the response should have a "slug" field
    And each project in the response should have a "slug" field
    And the response should include workspace slug "product-team"
