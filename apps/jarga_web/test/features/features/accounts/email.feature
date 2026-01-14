Feature: Email Management
  As a registered user
  I want to change my email address
  So that I can keep my account information up to date

  Scenario: User requests email change with valid token
    Given a confirmed user exists with email "alice@example.com"
    And an email change token is generated for changing to "newalice@example.com"
    When I update the email using the change token
    Then the email update should be successful
    And the user email should be "newalice@example.com"
    And all email change tokens should be deleted

  Scenario: User requests email change with invalid token
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the email with an invalid token
    Then the email update should fail with error "transaction_aborted"

  Scenario: User requests email change to duplicate email
    Given a confirmed user exists with email "alice@example.com"
    And a user exists with email "existing@example.com"
    And an email change token is generated for changing to "existing@example.com"
    When I attempt to update the email using the change token
    Then the email update should fail

  Scenario: User requests email change instructions
    Given a confirmed user exists with email "alice@example.com"
    When I request email update instructions for changing to "newalice@example.com"
    Then an email change token should be generated with context "change:alice@example.com"
    And the token should be persisted in the database
    And a confirmation email should be sent to "newalice@example.com"
    And the email should contain the confirmation URL

  Scenario: Generate email changeset for user
    Given a confirmed user exists with email "alice@example.com"
    When I generate an email changeset with new email "newalice@example.com"
    Then the changeset should include the new email
    And the changeset should have email validation rules
