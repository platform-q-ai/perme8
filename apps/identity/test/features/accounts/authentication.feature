Feature: User Authentication
  As a registered user
  I want to log in to my account
  So that I can access protected features

  # Magic Link Authentication

  Scenario: Confirmed user logs in with magic link
    Given a confirmed user exists with email "alice@example.com"
    And a magic link token is generated for "alice@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the magic link token should be deleted
    And no other tokens should be deleted

  Scenario: Unconfirmed user without password logs in with magic link
    Given an unconfirmed user exists with email "bob@example.com"
    And the user has no password set
    And a magic link token is generated for "bob@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the user should be confirmed
    And all user tokens should be deleted for security
    And the confirmed_at timestamp should be set

  Scenario: Unconfirmed user with password logs in with magic link
    Given an unconfirmed user exists with email "charlie@example.com"
    And the user has a password set
    And a magic link token is generated for "charlie@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the user should be confirmed
    And only the magic link token should be deleted
    And other session tokens should remain intact

  Scenario: User attempts login with invalid magic link token
    When I attempt to login with an invalid magic link token
    Then the login should fail with error "invalid_token"

  Scenario: User attempts login with expired magic link token
    Given a confirmed user exists with email "diana@example.com"
    And an expired magic link token exists for "diana@example.com"
    When I attempt to login with the expired token
    Then the login should fail with error "not_found"

  Scenario: Magic link confirmation sets confirmed_at timestamp
    Given an unconfirmed user exists with email "bob@example.com"
    And a magic link token is generated for "bob@example.com"
    When I login with the magic link token
    Then the confirmed_at timestamp should be set to current time
    And the timestamp should be in UTC

  # Password-Based Authentication

  Scenario: Confirmed user logs in with email and password
    Given a confirmed user exists with email "alice@example.com" and password "SecurePassword123!"
    When I login with email "alice@example.com" and password "SecurePassword123!"
    Then the login should be successful
    And I should receive the user record

  Scenario: User logs in with correct password but unconfirmed email
    Given an unconfirmed user exists with email "bob@example.com" and password "SecurePassword123!"
    When I attempt to login with email "bob@example.com" and password "SecurePassword123!"
    Then the login should fail
    And I should not receive a user record

  Scenario: User logs in with incorrect password
    Given a confirmed user exists with email "alice@example.com" and password "CorrectPassword123!"
    When I attempt to login with email "alice@example.com" and password "WrongPassword123!"
    Then the login should fail
    And I should not receive a user record

  Scenario: User logs in with non-existent email
    When I attempt to login with email "nonexistent@example.com" and password "AnyPassword123!"
    Then the login should fail
    And I should not receive a user record

  Scenario: Password verification with timing attack protection
    When I verify a password for a non-existent user
    Then Bcrypt.no_user_verify should be called
    And the result should be false

  # Magic Link Delivery

  Scenario: User requests magic link login instructions
    Given a confirmed user exists with email "alice@example.com"
    When I request login instructions for "alice@example.com"
    Then a login token should be generated with context "login"
    And the token should be persisted in the database
    And a magic link email should be sent to "alice@example.com"
    And the email should contain the magic link URL

  Scenario: Magic link token cannot be used as session token
    Given a confirmed user exists with email "alice@example.com"
    And a magic link token is generated for "alice@example.com"
    When I attempt to retrieve the user by session token using the magic link token
    Then I should not receive a user record
