Feature: LiveView Authentication UI
  As a user
  I want to use the login and registration pages
  So that I can authenticate through the web interface

  # Login Page Tests

  Scenario: Login page displays correctly
    When I visit the login page
    Then I should see the login form
    And I should see a link to register
    And I should see the magic link option

  Scenario: User requests magic link via UI
    Given a confirmed user exists with email "alice@example.com"
    When I visit the login page
    And I enter "alice@example.com" in the email field
    And I click the magic link button
    Then I should be redirected with a flash message about email

  Scenario: User logs in with password via UI
    Given a confirmed user exists with email "alice@example.com" and password "SecurePassword123!"
    When I visit the login page
    And I enter "alice@example.com" in the email field
    And I enter "SecurePassword123!" in the password field
    And I submit the login form
    Then I should be logged in successfully
    And I should see a welcome message

  Scenario: User sees error for wrong password
    Given a confirmed user exists with email "alice@example.com" and password "SecurePassword123!"
    When I visit the login page
    And I enter "alice@example.com" in the email field
    And I enter "WrongPassword123!" in the password field
    And I submit the login form
    Then I should see an error message about invalid credentials

  # Registration Page Tests

  Scenario: Registration page displays correctly
    When I visit the registration page
    Then I should see the registration form
    And I should see a link to login

  Scenario: User registers successfully via UI
    When I visit the registration page
    And I fill in the registration form with valid details
    And I submit the registration form
    Then I should see registration success message

  Scenario: Registration shows validation errors for short password
    When I visit the registration page
    And I enter a password shorter than 12 characters
    Then I should see password length error in the UI

  Scenario: Registration shows validation errors for invalid email
    When I visit the registration page
    And I enter "not-an-email" as email
    Then I should see email format error in the UI

  # Navigation Tests

  Scenario: User navigates from login to registration
    When I visit the login page
    And I click the register link
    Then I should be on the registration page

  Scenario: User navigates from registration to login
    When I visit the registration page
    And I click the login link
    Then I should be on the login page
