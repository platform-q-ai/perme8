Feature: Password Management
  As a registered user
  I want to manage my password
  So that I can keep my account secure

  Scenario: User updates their password
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    When I update the password to "NewPassword123!" with confirmation "NewPassword123!"
    Then the password update should be successful
    And the password should be hashed with bcrypt
    And all user tokens should be deleted for security
    And I should receive a list of expired tokens

  Scenario: User updates password with mismatched confirmation
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the password to "NewPassword123!" with confirmation "DifferentPassword123!"
    Then the password update should fail
    And I should see a password confirmation mismatch error

  Scenario: User updates password with short new password
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the password to "short" with confirmation "short"
    Then the password update should fail
    And I should see a password length validation error

  Scenario: Transaction rollback on password update failure
    Given a confirmed user exists with email "alice@example.com"
    When the password update fails during transaction
    Then the user password should remain unchanged
    And no tokens should be deleted

  Scenario: Generate password changeset for user
    Given a confirmed user exists with email "alice@example.com"
    When I generate a password changeset with new password "NewPassword123!"
    Then the changeset should include the new password
    And the changeset should have password validation rules
