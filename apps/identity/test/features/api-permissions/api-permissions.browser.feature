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
    And I fill "[data-testid='api-key-name-input']" with "Permission Full Access Key"
    And I click "[data-testid='permission-preset-full-access']"
    And I click the "Create API Key" button
    And I wait for network idle
    Then I should see "This token is shown only once"
    And "#api_key_token" should be visible
    When I click the "I've copied the key" button
    And I wait for network idle
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
    And I fill "[data-testid='api-key-name-input']" with "Permission Read Only Key"
    And I click "[data-testid='permission-preset-read-only']"
    And I click the "Create API Key" button
    And I wait for network idle
    Then I should see "This token is shown only once"
    When I click the "I've copied the key" button
    And I wait for network idle
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
    And I fill "[data-testid='api-key-name-input']" with "Permission Custom Key"
    And I click "[data-testid='permission-preset-custom']"
    And I check "[data-testid='scope-agents-read']"
    And I check "[data-testid='scope-agents-write']"
    And I click the "Create API Key" button
    And I wait for network idle
    Then I should see "This token is shown only once"
    When I click the "I've copied the key" button
    And I wait for network idle
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
    And I fill "[data-testid='api-key-name-input']" with "Permission Editable Key"
    And I click "[data-testid='permission-preset-full-access']"
    And I click the "Create API Key" button
    And I wait for network idle
    And I click the "I've copied the key" button
    And I wait for network idle
    # Now edit the key
    And I click "[data-testid='edit-api-key-permission-editable-key']"
    And I click "[data-testid='permission-preset-read-only']"
    And I click the "Save Changes" button
    And I wait for network idle
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
    And I click "[data-testid='permission-preset-custom']"
    Then "[data-testid='scope-agents-read']" should be visible
    And "[data-testid='scope-agents-write']" should be visible
    And "[data-testid='scope-agents-read']" should be checked
    And "[data-testid='scope-agents-write']" should be checked

  Scenario: Existing API keys with nil permissions display as Full Access
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    # Create a key with Full Access preset (nil permissions = full access)
    And I click the "New API Key" button
    And I fill "[data-testid='api-key-name-input']" with "Legacy Style Key"
    And I click "[data-testid='permission-preset-full-access']"
    And I click the "Create API Key" button
    And I wait for network idle
    And I click the "I've copied the key" button
    And I wait for network idle
    Then I should see "Legacy Style Key"
    And I should see "Full Access"
    When I click "[data-testid='edit-api-key-legacy-style-key']"
    Then "[data-testid='permission-preset-full-access']" should be visible
