Feature: Project API Access
  As a developer
  I want to create and retrieve projects via REST API using API keys
  So that I can integrate project management with external systems

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

  # Project POST Endpoint - Create projects
  Scenario: User creates project via API key
    Given I am logged in as "alice@example.com"
    And I have an API key "project-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "project-key" and body:
      """
      {
        "name": "Q1 Launch",
        "description": "Q1 product launch project"
      }
      """
    Then the response status should be 201
    And the response should include project "Q1 Launch"
    And the response should include description "Q1 product launch project"
    And the project should exist in workspace "product-team"
    And the response should include workspace slug "product-team"

  Scenario: User creates project with minimal data
    Given I am logged in as "alice@example.com"
    And I have an API key "project-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "project-key" and body:
      """
      {
        "name": "Simple Project"
      }
      """
    Then the response status should be 201
    And the response should include project "Simple Project"
    And the project should exist in workspace "product-team"

  Scenario: Create project with invalid data
    Given I am logged in as "alice@example.com"
    And I have an API key "project-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "project-key" and body:
      """
      {
        "description": "Project without name"
      }
      """
    Then the response status should be 422
    And the response should include validation error for "name"

  Scenario: API key without workspace access cannot create project
    Given I am logged in as "alice@example.com"
    And I have an API key "wrong-key" with access to "engineering"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "wrong-key" and body:
      """
      {
        "name": "Unauthorized Project",
        "description": "Should not be created"
      }
      """
    Then the response status should be 403
    And the response should include error "Insufficient permissions"
    And the project "Unauthorized Project" should not exist

  Scenario: API key with guest role cannot create project
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "guest" role in workspace "product-team"
    And I have an API key "guest-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "guest-key" and body:
      """
      {
        "name": "Should Fail",
        "description": "User doesn't have permission"
      }
      """
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: API key with owner permissions can create projects
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "owner" role in workspace "product-team"
    And I have an API key "owner-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "owner-key" and body:
      """
      {
        "name": "Owner Created Project",
        "description": "Created by owner"
      }
      """
    Then the response status should be 201
    And the project "Owner Created Project" should exist in workspace "product-team"

  Scenario: API key with member permissions can create projects
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "member" role in workspace "product-team"
    And I have an API key "member-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "member-key" and body:
      """
      {
        "name": "Member Created Project",
        "description": "Created by member"
      }
      """
    Then the response status should be 201
    And the project "Member Created Project" should exist in workspace "product-team"

  Scenario: Revoked API key cannot create project
    Given I am logged in as "alice@example.com"
    And I have a revoked API key "revoked-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "revoked-key" and body:
      """
      {
        "name": "Should Fail",
        "description": "Revoked key"
      }
      """
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Invalid API key cannot create project
    When I make a POST request to "/api/workspaces/product-team/projects" with API key "invalid-key-12345" and body:
      """
      {
        "name": "Should Fail",
        "description": "Invalid key"
      }
      """
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  # Project GET Endpoint - Retrieve specific project
  Scenario: User retrieves project via API key
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch" and description "Q1 product launch"
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "read-key"
    Then the response status should be 200
    And the response should include project "Q1 Launch"
    And the response should include description "Q1 product launch"
    And the response should include workspace slug "product-team"

  Scenario: Project response includes associated documents
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    And project "Q1 Launch" has the following documents:
      | Title           | Content         |
      | Launch Plan     | Plan details    |
      | Marketing Brief | Brief details   |
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "read-key"
    Then the response status should be 200
    And the response should include project "Q1 Launch"
    And the response should include 2 documents
    And the response should include document "Launch Plan" with slug
    And the response should include document "Marketing Brief" with slug

  Scenario: API key cannot access project in workspace it doesn't have access to
    Given I am logged in as "alice@example.com"
    And I have an API key "eng-key" with access to "engineering"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "eng-key"
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: Project not found returns 404
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    When I make a GET request to "/api/workspaces/product-team/projects/non-existent-project" with API key "read-key"
    Then the response status should be 404
    And the response should include error "Project not found"

  Scenario: Revoked API key cannot retrieve project
    Given I am logged in as "alice@example.com"
    And I have a revoked API key "revoked-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "revoked-key"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Invalid API key cannot retrieve project
    Given workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "invalid-key-12345"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: User with guest role can retrieve project
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "guest" role in workspace "product-team"
    And I have an API key "guest-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a GET request to "/api/workspaces/product-team/projects/q1-launch" with API key "guest-key"
    Then the response status should be 200
    And the response should include project "Q1 Launch"
