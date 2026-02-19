@browser
Feature: Account Settings
  As an authenticated user
  I want to manage my account email and password from the settings page
  So that I can keep my credentials up to date

  # ---------------------------------------------------------------------------
  # Authentication helper
  # Each scenario logs in via the password form which also activates sudo mode,
  # a requirement for SettingsLive.
  # ---------------------------------------------------------------------------

  Background:
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ---------------------------------------------------------------------------
  # Settings Page -- Display
  # ---------------------------------------------------------------------------

  Scenario: Settings page displays correctly for authenticated user
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    Then I should see "Account Settings"
    And I should see "Manage your account email address and password settings"
    And "#email_form" should be visible
    And "#password_form" should be visible

  Scenario: Settings page shows current user email in the email form
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    Then "#email_form" should be visible
    And "#user_email" should have value "${testEmail}"

  Scenario: Settings page shows the API Keys link
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    Then I should see "API Keys"
    And I should see "Manage API keys for external integrations"

  # ---------------------------------------------------------------------------
  # Email Change -- Validation
  # ---------------------------------------------------------------------------

  Scenario: Email form shows validation error for invalid email
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    When I clear "#user_email"
    And I fill "#user_email" with "not-an-email"
    And I click the "Change Email" button
    And I wait for 2 seconds
    Then I should see "must have the @ sign and no spaces"

  Scenario: Email form shows validation error when email unchanged
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    When I click the "Change Email" button
    And I wait for 2 seconds
    Then I should see "did not change"

  # ---------------------------------------------------------------------------
  # Password Change -- Validation
  # ---------------------------------------------------------------------------

  Scenario: Password form shows validation error for short password
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    When I fill "#user_password" with "short"
    And I click the "Save Password" button
    And I wait for 2 seconds
    Then I should see "should be at least 12 character(s)"

  Scenario: Password form shows validation error for mismatched confirmation
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    When I fill "#user_password" with "NewSecurePassword123!"
    And I fill "#user_password_confirmation" with "DifferentPassword123!"
    And I click the "Save Password" button
    And I wait for 2 seconds
    Then I should see "does not match password"

  # ---------------------------------------------------------------------------
  # Navigation -- Settings to API Keys
  # ---------------------------------------------------------------------------

  Scenario: User navigates from settings to API keys page
    Given I navigate to "${baseUrl}/users/settings"
    And I wait for network idle
    When I click the "API Keys" link
    And I wait for network idle
    Then the URL should contain "/users/settings/api-keys"
    And I should see "API Keys"
