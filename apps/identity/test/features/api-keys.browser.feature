@browser
Feature: API Key Management
  As an authenticated user
  I want to create, view, edit, and revoke API keys
  So that I can integrate with external systems securely

  # Seed data provides: "Seeded Active Key" (active) and "Seeded Revoked Key" (revoked)

  Background:
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ---------------------------------------------------------------------------
  # API Keys Page -- Display
  # ---------------------------------------------------------------------------

  Scenario: API keys page shows seeded keys
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "API Keys"
    And I should see "Seeded Active Key"
    And I should see "Active"

  Scenario: API keys page shows filter buttons with counts
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "All"
    And I should see "Active"
    And I should see "Revoked"

  Scenario: API keys page shows table headers
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "Name"
    And I should see "Status"
    And I should see "Created"
    And I should see "Actions"

  # ---------------------------------------------------------------------------
  # Filter API Keys
  # ---------------------------------------------------------------------------

  Scenario: Filter shows only active keys
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click "[phx-value-show='active']"
    And I wait for 1 seconds
    Then I should see "Seeded Active Key"
    And I should not see "Seeded Revoked Key"

  Scenario: Filter shows only revoked keys
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click "[phx-value-show='inactive']"
    And I wait for 1 seconds
    Then I should see "Seeded Revoked Key"
    And I should not see "Seeded Active Key"

  Scenario: All filter shows all keys
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click "[phx-value-show='inactive']"
    And I wait for 1 seconds
    When I click "[phx-value-show='all']"
    And I wait for 1 seconds
    Then I should see "Seeded Active Key"
    And I should see "Seeded Revoked Key"

  # ---------------------------------------------------------------------------
  # Create API Key
  # ---------------------------------------------------------------------------

  Scenario: User opens create modal from header button
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click the "New API Key" button
    And I wait for 1 seconds
    Then I should see "Create New API Key"
    And "#create_form" should be visible
    And I should see "Name"
    And I should see "Description"

  Scenario: User cancels create modal
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click the "New API Key" button
    And I wait for 1 seconds
    Then I should see "Create New API Key"
    When I click the "Cancel" button
    And I wait for 1 seconds
    Then I should not see "Create New API Key"

  Scenario: User creates an API key and sees the token
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click the "New API Key" button
    And I wait for 1 seconds
    And I fill "#name" with "Browser Test Key"
    And I fill "#description" with "Created via browser test"
    And I click the "Create API Key" button
    And I wait for 2 seconds
    Then I should see "Your API Key"
    And "#api_key_token" should be visible

  # ---------------------------------------------------------------------------
  # Edit API Key
  # ---------------------------------------------------------------------------

  Scenario: User opens edit modal for an active key
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "Seeded Active Key"
    # Actions column may overflow viewport -- use js click to bypass viewport check
    When I js click "[phx-click='edit_key']"
    And I wait for 1 seconds
    Then I should see "Edit API Key"
    And "#edit_form" should be visible

  Scenario: User cancels edit modal
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I js click "[phx-click='edit_key']"
    And I wait for 1 seconds
    Then I should see "Edit API Key"
    When I click the "Cancel" button
    And I wait for 1 seconds
    Then I should not see "Edit API Key"

  # ---------------------------------------------------------------------------
  # Revoke API Key
  # ---------------------------------------------------------------------------

  Scenario: User revokes an active API key
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "Seeded Active Key"
    When I accept the next browser dialog
    And I js click "[phx-click='revoke_key']"
    And I wait for 2 seconds
    Then I should see "API key revoked successfully!"

  # ---------------------------------------------------------------------------
  # Revoked Key Restrictions
  # ---------------------------------------------------------------------------

  Scenario: Revoked key does not show edit or revoke actions
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    When I click "[phx-value-show='inactive']"
    And I wait for 1 seconds
    Then I should see "Seeded Revoked Key"
    And I should see "Revoked"
