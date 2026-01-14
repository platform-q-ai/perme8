Feature: User Registration
  As a new user
  I want to register for an account
  So that I can access the application

  Scenario: User registers with valid credentials
    When I register with the following details:
      | Field       | Value                 |
      | email       | alice@example.com     |
      | password    | SecurePassword123!    |
      | first_name  | Alice                 |
      | last_name   | Smith                 |
    Then the registration should be successful
    And the user should have email "alice@example.com"
    And the user should have first name "Alice"
    And the user should have last name "Smith"
    And the user should have status "active"
    And the user should not be confirmed
    And the password should be hashed with bcrypt

  Scenario: User registers without required fields
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | incomplete@example.com|
      | password    | SecurePassword123!    |
    Then the registration should fail
    And I should see validation errors for "first_name"
    And I should see validation errors for "last_name"

  Scenario: User registers with invalid email format
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | invalid-email         |
      | password    | SecurePassword123!    |
      | first_name  | Bob                   |
      | last_name   | Jones                 |
    Then the registration should fail
    And I should see an email format validation error

  Scenario: User registers with short password
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | bob@example.com       |
      | password    | short                 |
      | first_name  | Bob                   |
      | last_name   | Jones                 |
    Then the registration should fail
    And I should see a password length validation error

  Scenario: User registers with duplicate email
    Given a user exists with email "existing@example.com"
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | existing@example.com  |
      | password    | SecurePassword123!    |
      | first_name  | Charlie               |
      | last_name   | Brown                 |
    Then the registration should fail
    And I should see a duplicate email error

  Scenario: Email is normalized to lowercase during registration
    When I register with email "UPPERCASE@EXAMPLE.COM"
    Then the user email should be stored as "uppercase@example.com"

  Scenario: Registration sets date_created timestamp
    When I register a new user
    Then the user should have a date_created timestamp
    And the timestamp should be within 5 seconds of now
