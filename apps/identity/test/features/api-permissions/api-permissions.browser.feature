@browser
Feature: API Key Permission Management
  As a developer managing API keys
  I want to configure granular permissions per API key
  So that I can enforce least-privilege access from the browser

  Scenario: Workspace member can log in and reach API Keys settings
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "API Keys"

  Scenario: Login with invalid credentials is rejected
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "invalid-user@example.com"
    And I fill "#login_form_password_password" with "invalid-password"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    Then the URL should contain "/log-in"
    And I should see "Invalid email or password"

  Scenario: Unauthenticated user is redirected when opening API Keys settings
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then the URL should contain "/log-in"

  Scenario: Create an API key with Full Access preset
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    And I click the "New API Key" button
    And I wait for 1 seconds
    And I fill "#name" with "Permission Full Access Key"
    And I click "[data-testid='permission-preset-full-access']"
    And I click the "Create API Key" button
    And I wait for 2 seconds
    Then I should see "Your API Key"
    And "#api_key_token" should be visible
    When I click the "I've copied the key" button
    And I wait for 1 seconds
    Then I should see "Permission Full Access Key"
    And I should see "Full Access"

  Scenario: Create an API key with Read Only preset
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    And I click the "New API Key" button
    And I wait for 1 seconds
    And I fill "#name" with "Permission Read Only Key"
    And I click "[data-testid='permission-preset-read-only']"
    And I click the "Create API Key" button
    And I wait for 2 seconds
    Then I should see "Your API Key"
    When I click the "I've copied the key" button
    And I wait for 1 seconds
    Then I should see "Permission Read Only Key"
    And I should see "Read Only"

  Scenario: Create an API key with Custom permissions
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    And I click the "New API Key" button
    And I wait for 1 seconds
    And I fill "#name" with "Permission Custom Key"
    And I click "[data-testid='permission-preset-custom']"
    And I wait for 1 seconds
    And I click the "Create API Key" button
    And I wait for 2 seconds
    Then I should see "Your API Key"
    When I click the "I've copied the key" button
    And I wait for 1 seconds
    Then I should see "Permission Custom Key"
    And I should see "Custom"

  Scenario: Edit an existing API key's permissions
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    # First create a key
    And I click the "New API Key" button
    And I wait for 1 seconds
    And I fill "#name" with "Permission Editable Key"
    And I click "[data-testid='permission-preset-full-access']"
    And I click the "Create API Key" button
    And I wait for 2 seconds
    And I click the "I've copied the key" button
    And I wait for 1 seconds
    # Now edit the key
    And I click "[data-testid='edit-api-key-permission-editable-key']"
    And I wait for 1 seconds
    And I click "[data-testid='permission-preset-read-only']"
    And I click the "Save Changes" button
    And I wait for 2 seconds
    Then I should see "Read Only"

  Scenario: Custom preset shows individual scope checkboxes
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    And I click the "New API Key" button
    And I wait for 1 seconds
    And I click "[data-testid='permission-preset-custom']"
    And I wait for 1 seconds
    Then "[data-testid='scope-agents-read']" should be visible
    And "[data-testid='scope-agents-write']" should be visible

  Scenario: Existing API keys with nil permissions display as Full Access
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    # The seeded key "Seeded Active Key" has nil permissions (created before permissions feature)
    Then I should see "Seeded Active Key"
    And I should see "Full Access"
