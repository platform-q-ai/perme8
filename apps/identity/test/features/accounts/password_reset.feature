Feature: Password Reset
  As a user who forgot my password
  I want to request and complete a password reset
  So that I can regain access to my account

  # Request Password Reset

  Scenario: Forgot password page displays correctly
    When I visit the forgot password page
    Then I should see the forgot password form
    And I should see a link to login

  Scenario: User requests password reset with valid email
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    When I visit the forgot password page
    And I enter "alice@example.com" in the reset email field
    And I submit the forgot password form
    Then I should be redirected with a reset password flash message
    And a reset password token should be created for the user

  Scenario: User requests password reset with invalid email
    When I visit the forgot password page
    And I enter "nonexistent@example.com" in the reset email field
    And I submit the forgot password form
    Then I should be redirected with a reset password flash message
    # Same message shown to prevent email enumeration

  # Reset Password with Token

  Scenario: Reset password page displays correctly with valid token
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    And the user has a reset password token
    When I visit the reset password page with the token
    Then I should see the reset password form
    And I should see password and confirmation fields

  Scenario: User resets password successfully
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    And the user has a reset password token
    When I visit the reset password page with the token
    And I enter "NewSecurePassword123!" as the new password
    And I confirm the new password with "NewSecurePassword123!"
    And I submit the reset password form
    Then I should see password reset success message
    And I should be redirected to login
    And I should be able to log in with the new password

  Scenario: User tries to reset password with invalid token
    When I visit the reset password page with an invalid token
    Then I should see token expired error message
    And I should be redirected to login

  Scenario: User tries to reset password with mismatched confirmation
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    And the user has a reset password token
    When I visit the reset password page with the token
    And I enter "NewSecurePassword123!" as the new password
    And I confirm the new password with "DifferentPassword123!"
    And I submit the reset password form
    Then I should see password confirmation mismatch error

  Scenario: User tries to reset password with short password
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    And the user has a reset password token
    When I visit the reset password page with the token
    And I enter "short" as the new password
    And I confirm the new password with "short"
    And I submit the reset password form
    Then I should see password length validation error

  # Token Expiration

  Scenario: User tries to use expired reset password token
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    And the user has an expired reset password token
    When I visit the reset password page with the token
    Then I should see token expired error message
    And I should be redirected to login

  # Navigation

  Scenario: User navigates from forgot password to login
    When I visit the forgot password page
    And I click the back to login link
    Then I should be on the login page

  Scenario: User navigates from login to forgot password
    When I visit the login page
    Then I should see a link to reset password
