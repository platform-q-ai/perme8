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

  Scenario: User requests magic link via UI
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_magic_email" with "alice@example.com"
    And I click the "Log in with email" button
    And I wait for 2 seconds
    Then I should see "If your email is in our system"

  Scenario: User sees error for wrong password
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "WrongPassword123!"
    And I click the "Log in and stay logged in" button
    And I wait for 2 seconds
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
    And I wait for network idle
    Then I should see "An email was sent to bob.tester@example.com"

  Scenario: Registration shows validation errors for short password
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I fill "#user_first_name" with "Bob"
    And I fill "#user_last_name" with "Tester"
    And I fill "#user_email" with "bob.short@example.com"
    And I fill "#user_password" with "short"
    And I click the "Create an account" button
    And I wait for 2 seconds
    Then I should see "should be at least 12 character(s)"

  Scenario: Registration shows validation errors for invalid email
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I fill "#user_first_name" with "Bob"
    And I fill "#user_last_name" with "Tester"
    And I fill "#user_email" with "not-an-email"
    And I fill "#user_password" with "SecurePassword123!"
    And I click the "Create an account" button
    And I wait for 2 seconds
    Then I should see "must have the @ sign and no spaces"

  # ---------------------------------------------------------------------------
  # Navigation between Login and Registration
  # ---------------------------------------------------------------------------

  Scenario: User navigates from login to registration
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I click the "Sign up" link
    And I wait for 2 seconds
    Then the URL should contain "/users/register"
    And I should see "Register for an account"

  Scenario: User navigates from registration to login
    Given I navigate to "${baseUrl}/users/register"
    And I wait for the page to load
    When I click the "Log in" link
    And I wait for 2 seconds
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
    And I wait for 2 seconds
    Then I should see "If your email is in our system"

  Scenario: User requests password reset with unknown email
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    When I fill "#user_email" with "nonexistent@example.com"
    And I click the "Send password reset instructions" button
    And I wait for 2 seconds
    Then I should see "If your email is in our system"

  Scenario: Reset password page displays correctly with valid token
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    Then I should see "Reset password"
    And "#reset_password_form" should be visible
    And "#user_password" should be visible
    And "#user_password_confirmation" should be visible

  Scenario: User tries to reset password with invalid token
    Given I navigate to "${baseUrl}/users/reset-password/invalid-token-value"
    And I wait for the page to load
    Then I should see "Reset password link is invalid or it has expired."

  Scenario: User tries to reset password with mismatched confirmation
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    When I fill "#user_password" with "NewSecurePassword123!"
    And I fill "#user_password_confirmation" with "DifferentPassword123!"
    And I click the "Reset password" button
    And I wait for 2 seconds
    Then I should see "does not match password"

  Scenario: User tries to reset password with short password
    Given I navigate to "${baseUrl}/users/reset-password/${resetToken}"
    And I wait for the page to load
    When I fill "#user_password" with "short"
    And I fill "#user_password_confirmation" with "short"
    And I click the "Reset password" button
    And I wait for 2 seconds
    Then I should see "should be at least 12 character(s)"

  Scenario: User navigates from forgot password to login
    Given I navigate to "${baseUrl}/users/reset-password"
    And I wait for the page to load
    When I click the "Back to log in" link
    And I wait for 2 seconds
    Then the URL should contain "/users/log-in"
    And I should see "Log in"

  Scenario: User navigates from login to forgot password
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I click the "Forgot your password?" link
    And I wait for 2 seconds
    Then the URL should contain "/users/reset-password"
    And I should see "Forgot your password?"
