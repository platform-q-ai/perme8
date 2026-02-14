@browser
Feature: Identity Browser UI
  As a user
  I want to use the Identity authentication pages in a browser
  So that I can register, log in, reset my password, and manage API keys

  # ---------------------------------------------------------------------------
  # Login Page
  # ---------------------------------------------------------------------------

  Scenario: Login page displays correctly
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    Then I should see "Log in"
    And "#login_form_magic" should be visible
    And "#login_form_password" should be visible
    And I should see "Sign up"
    And I should see "Log in with email"

  Scenario: User requests magic link via UI
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_magic_email" with "alice@example.com"
    And I click the "Log in with email" button
    And I wait for the page to load
    Then I should see "If your email is in our system, you will receive instructions for logging in shortly."

  Scenario: User logs in with password via UI
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "SecurePassword123!"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    Then I should see "Welcome back!"

  Scenario: User sees error for wrong password
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "WrongPassword123!"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    Then I should see "Invalid email or password"

  # ---------------------------------------------------------------------------
  # Registration Page
  # ---------------------------------------------------------------------------

  Scenario: Registration page displays correctly
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    Then I should see "Register for an account"
    And "#registration_form" should be visible
    And I should see "Log in"

  Scenario: User registers successfully via UI
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I fill "#user_first_name" with "Bob"
    And I fill "#user_last_name" with "Tester"
    And I fill "#user_email" with "bob.tester@example.com"
    And I fill "#user_password" with "SecurePassword123!"
    And I click the "Create an account" button
    And I wait for the page to load
    Then I should see "An email was sent to bob.tester@example.com"

  Scenario: Registration shows validation errors for short password
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I fill "#user_first_name" with "Bob"
    And I fill "#user_last_name" with "Tester"
    And I fill "#user_email" with "bob.short@example.com"
    And I fill "#user_password" with "short"
    And I click the "Create an account" button
    And I wait for 1 seconds
    Then I should see "should be at least 12 character(s)"

  Scenario: Registration shows validation errors for invalid email
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I fill "#user_first_name" with "Bob"
    And I fill "#user_last_name" with "Tester"
    And I fill "#user_email" with "not-an-email"
    And I fill "#user_password" with "SecurePassword123!"
    And I click the "Create an account" button
    And I wait for 1 seconds
    Then I should see "must have the @ sign and no spaces"

  # ---------------------------------------------------------------------------
  # Navigation between Login and Registration
  # ---------------------------------------------------------------------------

  Scenario: User navigates from login to registration
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I click the "Sign up" link
    And I wait for the page to load
    Then the URL should contain "/users/register"
    And I should see "Register for an account"

  Scenario: User navigates from registration to login
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I click the "Log in" link
    And I wait for the page to load
    Then the URL should contain "/users/log-in"
    And I should see "Log in"

  # ---------------------------------------------------------------------------
  # Forgot Password Page
  # ---------------------------------------------------------------------------

  Scenario: Forgot password page displays correctly
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    Then I should see "Forgot your password?"
    And "#reset_password_form" should be visible
    And I should see "Back to log in"

  Scenario: User requests password reset with valid email
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    When I fill "#user_email" with "alice@example.com"
    And I click the "Send password reset instructions" button
    And I wait for the page to load
    Then I should see "If your email is in our system, you will receive password reset instructions shortly."

  Scenario: User requests password reset with invalid email
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    When I fill "#user_email" with "nonexistent@example.com"
    And I click the "Send password reset instructions" button
    And I wait for the page to load
    Then I should see "If your email is in our system, you will receive password reset instructions shortly."

  Scenario: Reset password page displays correctly with valid token
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    Then I should see "Reset password"
    And "#reset_password_form" should be visible
    And "#user_password" should be visible
    And "#user_password_confirmation" should be visible

  Scenario: User resets password successfully
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    When I fill "#user_password" with "NewSecurePassword123!"
    And I fill "#user_password_confirmation" with "NewSecurePassword123!"
    And I click the "Reset password" button
    And I wait for the page to load
    Then I should see "Password reset successfully."
    And the URL should contain "/users/log-in"

  Scenario: User tries to reset password with invalid token
    Given I navigate to "${baseUrl}/users/reset-password/invalid-token-value"
    And I wait for the page to load
    Then I should see "Reset password link is invalid or it has expired."
    And the URL should contain "/users/log-in"

  Scenario: User tries to reset password with mismatched confirmation
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    When I fill "#user_password" with "NewSecurePassword123!"
    And I fill "#user_password_confirmation" with "DifferentPassword123!"
    And I click the "Reset password" button
    And I wait for 1 seconds
    Then I should see "does not match password"

  Scenario: User tries to reset password with short password
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    When I fill "#user_password" with "short"
    And I fill "#user_password_confirmation" with "short"
    And I click the "Reset password" button
    And I wait for 1 seconds
    Then I should see "should be at least 12 character(s)"

  Scenario: User navigates from forgot password to login
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    When I click the "Back to log in" link
    And I wait for the page to load
    Then the URL should contain "/users/log-in"
    And I should see "Log in"

  Scenario: User navigates from login to forgot password
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I click the "Forgot your password?" link
    And I wait for the page to load
    Then the URL should contain "/users/reset-password"
    And I should see "Forgot your password?"

  # ---------------------------------------------------------------------------
  # API Key Management (requires authenticated user)
  # ---------------------------------------------------------------------------

  Scenario: API keys page displays correctly when empty
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    Then I should see "API Keys"
    And I should see "No API keys yet"
    And I should see "New API Key"

  Scenario: User creates an API key with workspace access
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    When I click the "New API Key" button
    And I wait for ".modal-open" to be visible
    And I fill "#create_form input[name='name']" with "Integration Key"
    And I fill "#create_form input[name='description']" with "For CI/CD integration"
    And I click "input[name='workspace_access[]'][value='product-team']"
    And I click the "Create API Key" button
    And I wait for "#api_key_token" to be visible
    Then I should see "Your API Key"
    And I should see "Copy this key now"
    And "#api_key_token" should be visible
    When I click the "I've copied the key" button
    And I wait for 1 seconds
    Then I should see "Integration Key"
    And I should see "API key created successfully!"

  Scenario: User revokes an API key
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    And I should see "Integration Key"
    When I click "button[phx-click='revoke_key']"
    And I wait for 1 seconds
    Then I should see "API key revoked successfully!"
    And I should see "Revoked"

  Scenario: User edits an API key name
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    And I should see "Old Name"
    When I click "button[phx-click='edit_key']"
    And I wait for ".modal-open" to be visible
    And I clear "#edit_form input[name='name']"
    And I fill "#edit_form input[name='name']" with "New Name"
    And I click the "Save Changes" button
    And I wait for 1 seconds
    Then I should see "API key updated successfully!"
    And I should see "New Name"

  Scenario: User sees token displayed only once after creation
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    When I click the "New API Key" button
    And I wait for ".modal-open" to be visible
    And I fill "#create_form input[name='name']" with "Secret Key"
    And I click the "Create API Key" button
    And I wait for "#api_key_token" to be visible
    Then "#api_key_token" should be visible
    And I store the text of "#api_key_token" as "createdToken"
    And the variable "createdToken" should exist
    When I click the "I've copied the key" button
    And I wait for 1 seconds
    Then I should see "Secret Key"
    And "#api_key_token" should not exist

  Scenario: API keys list shows filter tabs
    Given I navigate to "${baseUrl}/users/settings/api-keys"
    And I wait for the page to load
    Then I should see "All"
    And I should see "Active"
    And I should see "Revoked"
