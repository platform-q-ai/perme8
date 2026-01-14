Feature: Session Management
  As a logged in user
  I want to manage my session
  So that I can stay logged in securely

  Scenario: User generates session token
    Given a confirmed user exists with email "alice@example.com"
    When I generate a session token for the user
    Then the session token should be created successfully
    And the token should be persisted in the database
    And the token context should be "session"
    And I should receive an encoded token binary

  Scenario: User retrieves account with valid session token
    Given a confirmed user exists with email "alice@example.com"
    And a valid session token exists for the user
    When I retrieve the user by session token
    Then I should receive the user record
    And I should receive the token inserted_at timestamp

  Scenario: User retrieves account with invalid session token
    When I attempt to retrieve a user with an invalid session token
    Then I should not receive a user record

  Scenario: User logs out and session token is deleted
    Given a confirmed user exists with email "alice@example.com"
    And a valid session token exists for the user
    When I delete the session token
    Then the token should be removed from the database
    And the operation should return :ok

  Scenario: User token expires after period
    Given a confirmed user exists with email "alice@example.com"
    And a session token was created 90 days ago
    When I attempt to retrieve the user by that session token
    Then I should not receive a user record

  # Sudo Mode

  Scenario: User in sudo mode (authenticated within 20 minutes)
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 10 minutes ago
    When I check if the user is in sudo mode
    Then the user should be in sudo mode

  Scenario: User not in sudo mode (authenticated over 20 minutes ago)
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 30 minutes ago
    When I check if the user is in sudo mode
    Then the user should not be in sudo mode

  Scenario: User not in sudo mode (never authenticated)
    Given a confirmed user exists with email "alice@example.com"
    And the user has no authenticated_at timestamp
    When I check if the user is in sudo mode
    Then the user should not be in sudo mode

  Scenario: User in sudo mode with custom time limit
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 8 minutes ago
    When I check if the user is in sudo mode with a 10 minute limit
    Then the user should be in sudo mode

  Scenario: User not in sudo mode with custom time limit
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 15 minutes ago
    When I check if the user is in sudo mode with a 10 minute limit
    Then the user should not be in sudo mode

  # User Lookup

  Scenario: Get user by email
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by email "alice@example.com"
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by email (case-insensitive)
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by email "ALICE@EXAMPLE.COM" using case-insensitive search
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by email when not found
    When I get the user by email "nonexistent@example.com"
    Then I should not receive a user record

  Scenario: Get user by ID
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by ID
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by ID when not found raises error
    When I attempt to get a user with non-existent ID
    Then an Ecto.NoResultsError should be raised
