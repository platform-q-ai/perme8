@http
Feature: Identity HTTP API
  As an API consumer
  I want to manage user authentication via the Identity HTTP endpoints
  So that I can register, log in, reset passwords, and manage sessions programmatically

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # User Registration — POST /users/register
  # ---------------------------------------------------------------------------

  Scenario: User registers with valid credentials
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "alice@example.com",
          "password": "SecurePassword123!",
          "first_name": "Alice",
          "last_name": "Smith"
        }
      }
      """
    Then the response should be successful
    And the response body should be valid JSON
    And the response body path "$.data.email" should equal "alice@example.com"
    And the response body path "$.data.first_name" should equal "Alice"
    And the response body path "$.data.last_name" should equal "Smith"
    And the response body path "$.data.id" should exist
    And I store response body path "$.data.id" as "userId"

  Scenario: Registration fails without required name fields
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "incomplete@example.com",
          "password": "SecurePassword123!"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.first_name" should exist
    And the response body path "$.errors.last_name" should exist

  Scenario: Registration fails with invalid email format
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "invalid-email",
          "password": "SecurePassword123!",
          "first_name": "Bob",
          "last_name": "Jones"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.email" should exist

  Scenario: Registration fails with short password
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "bob@example.com",
          "password": "short",
          "first_name": "Bob",
          "last_name": "Jones"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.password" should exist

  Scenario: Registration fails with duplicate email
    # First registration — should succeed
    Given I set header "Content-Type" to "application/json"
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "existing@example.com",
          "password": "SecurePassword123!",
          "first_name": "First",
          "last_name": "User"
        }
      }
      """
    Then the response should be successful
    # Second registration with same email — should fail
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    When I POST to "/users/register" with body:
      """
      {
        "user": {
          "email": "existing@example.com",
          "password": "SecurePassword123!",
          "first_name": "Second",
          "last_name": "User"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.email" should exist

  # ---------------------------------------------------------------------------
  # Session Management — POST /users/log-in, DELETE /users/log-out
  # ---------------------------------------------------------------------------

  Scenario: User logs in with valid email and password
    # Pre-register and confirm a user (assumes seed data or prior registration)
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "email": "alice@example.com",
          "password": "SecurePassword123!"
        }
      }
      """
    Then the response status should be between 200 and 302
    And the response header "set-cookie" should exist

  Scenario: Login fails with incorrect password
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "email": "alice@example.com",
          "password": "WrongPassword999!"
        }
      }
      """
    Then the response status should not be 200
    And the response header "set-cookie" should exist

  Scenario: Login fails with non-existent email
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "email": "nobody@example.com",
          "password": "AnyPassword123!"
        }
      }
      """
    Then the response status should not be 200

  Scenario: User logs out via DELETE and session is cleared
    # First log in to get a session
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "email": "alice@example.com",
          "password": "SecurePassword123!"
        }
      }
      """
    Then the response header "set-cookie" should exist
    And I store response header "set-cookie" as "sessionCookie"
    # Now log out
    Given I set header "Content-Type" to "application/json"
    And I set header "cookie" to "${sessionCookie}"
    When I DELETE "/users/log-out"
    Then the response status should be between 200 and 302

  # ---------------------------------------------------------------------------
  # Password Reset — POST /users/reset-password, PUT /users/reset-password/:token
  # ---------------------------------------------------------------------------

  Scenario: User requests password reset with valid email
    When I POST to "/users/reset-password" with body:
      """
      {
        "user": {
          "email": "alice@example.com"
        }
      }
      """
    # Always succeeds to prevent email enumeration
    Then the response should be successful

  Scenario: User requests password reset with non-existent email
    When I POST to "/users/reset-password" with body:
      """
      {
        "user": {
          "email": "nonexistent@example.com"
        }
      }
      """
    # Returns success even for unknown emails to prevent enumeration
    Then the response should be successful

  Scenario: Password reset succeeds with valid token and new password
    Given I set variable "resetToken" to "valid-reset-token"
    When I PUT to "/users/reset-password/${resetToken}" with body:
      """
      {
        "user": {
          "password": "NewPassword123!",
          "password_confirmation": "NewPassword123!"
        }
      }
      """
    Then the response should be successful

  Scenario: Password reset fails with invalid token
    When I PUT to "/users/reset-password/invalid-token-abc123" with body:
      """
      {
        "user": {
          "password": "NewPassword123!",
          "password_confirmation": "NewPassword123!"
        }
      }
      """
    Then the response should be a client error

  Scenario: Password reset fails with mismatched password confirmation
    Given I set variable "resetToken" to "valid-reset-token"
    When I PUT to "/users/reset-password/${resetToken}" with body:
      """
      {
        "user": {
          "password": "NewPassword123!",
          "password_confirmation": "DifferentPassword123!"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.password_confirmation" should exist

  Scenario: Password reset fails with short password
    Given I set variable "resetToken" to "valid-reset-token"
    When I PUT to "/users/reset-password/${resetToken}" with body:
      """
      {
        "user": {
          "password": "short",
          "password_confirmation": "short"
        }
      }
      """
    Then the response should be a client error
    And the response body should be valid JSON
    And the response body path "$.errors.password" should exist

  # ---------------------------------------------------------------------------
  # Magic Link Authentication — POST /users/log-in with token
  # ---------------------------------------------------------------------------

  Scenario: User logs in via magic link token
    Given I set variable "magicToken" to "valid-magic-link-token"
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "token": "${magicToken}"
        }
      }
      """
    Then the response status should be between 200 and 302
    And the response header "set-cookie" should exist

  Scenario: Magic link login fails with invalid token
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "token": "invalid-magic-token-abc123"
        }
      }
      """
    Then the response status should not be 200

  Scenario: Magic link login fails with expired token
    Given I set variable "expiredToken" to "expired-magic-link-token"
    When I POST to "/users/log-in" with body:
      """
      {
        "user": {
          "token": "${expiredToken}"
        }
      }
      """
    Then the response status should not be 200
