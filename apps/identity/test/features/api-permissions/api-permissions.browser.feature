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

  Scenario: Create an API key with Full Access preset shows token
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

  Scenario: Create an API key with Read Only preset shows token
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

  Scenario: Permission preset buttons are visible in create modal
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    And I click the "New API Key" button
    And I wait for 1 seconds
    Then "[data-testid='permission-preset-full-access']" should be visible
    And "[data-testid='permission-preset-read-only']" should be visible
    And "[data-testid='permission-preset-agent-operator']" should be visible
    And "[data-testid='permission-preset-custom']" should be visible

  Scenario: Existing seeded API key displays Full Access badge
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for network idle
    Then I should see "Seeded Active Key"
    And I should see "Full Access"
