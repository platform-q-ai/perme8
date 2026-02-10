Feature: API Key Management
  As a user
  I want to manage API keys with workspace-specific access
  So that I can securely integrate with external systems

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

  # API Key Creation
  Scenario: User creates an API key with workspace access
    Given I am logged in as "alice@example.com"
    When I create an API key with the following details:
      | Name                | Description                      | Workspace Access      |
      | Integration Key     | For CI/CD integration           | product-team          |
    Then the API key should be created successfully
    And I should receive the API key token
    And the API key should have access to workspace "product-team"
    And the API key should not have access to workspace "engineering"

  Scenario: User creates an API key with multiple workspace access
    Given I am logged in as "alice@example.com"
    When I create an API key with the following details:
      | Name                | Description                      | Workspace Access              |
      | Multi-Workspace Key | Access to multiple workspaces   | product-team,engineering      |
    Then the API key should be created successfully
    And the API key should have access to workspace "product-team"
    And the API key should have access to workspace "engineering"

  Scenario: User creates an API key without workspace access specified
    Given I am logged in as "alice@example.com"
    When I create an API key with the following details:
      | Name                | Description                      |
      | No Access Key       | Key with no workspace access    |
    Then the API key should be created successfully
    And the API key should not have access to any workspace

  Scenario: User cannot create API key with access to workspace they don't belong to
    Given I am logged in as "alice@example.com"
    When I attempt to create an API key with access to workspace "marketing"
    Then I should receive a forbidden error
    And the API key should not be created

  # API Key Listing
  Scenario: User lists their API keys
    Given I am logged in as "alice@example.com"
    And I have the following API keys:
      | Name                | Workspace Access      | Created At       |
      | Integration Key     | product-team          | 2026-01-01       |
      | Multi-Workspace Key | product-team,engineering | 2026-01-02    |
    When I view my API keys
    Then I should see 2 API keys
    And I should see the API key "Integration Key" with workspace access "product-team"
    And I should see the API key "Multi-Workspace Key" with workspace access "product-team,engineering"
    And I should not see the actual API key tokens

  # API Key Revocation
  Scenario: User revokes an API key
    Given I am logged in as "alice@example.com"
    And I have an API key named "Integration Key"
    When I revoke the API key "Integration Key"
    Then the API key should be revoked successfully
    And the API key "Integration Key" should no longer be usable

  Scenario: User cannot revoke another user's API key
    Given I am logged in as "alice@example.com"
    And "bob@example.com" has an API key named "Bob's Key"
    When I attempt to revoke the API key "Bob's Key"
    Then I should receive a forbidden error

  # API Key Update
  Scenario: User updates API key workspace access
    Given I am logged in as "alice@example.com"
    And I have an API key named "Integration Key" with access to "product-team"
    When I update the API key "Integration Key" to have access to "product-team,engineering"
    Then the API key should be updated successfully
    And the API key should have access to workspace "product-team"
    And the API key should have access to workspace "engineering"

  Scenario: User updates API key name and description
    Given I am logged in as "alice@example.com"
    And I have an API key named "Old Name"
    When I update the API key with the following details:
      | Name        | Description           |
      | New Name    | Updated description   |
    Then the API key should be updated successfully
    And the API key should have name "New Name"
    And the API key should have description "Updated description"

  # API Key Security
  Scenario: API key is only shown once upon creation
    Given I am logged in as "alice@example.com"
    When I create an API key with name "Secret Key"
    Then I should receive the API key token
    When I view my API keys
    Then I should see the API key "Secret Key"
    But I should not see the actual API key token

  Scenario: API key tokens are securely hashed in database
    Given I am logged in as "alice@example.com"
    When I create an API key with name "Secure Key"
    Then I should receive the API key token
    And the API key token should not be stored in plain text in the database
    And the API key should be stored with a secure hash
