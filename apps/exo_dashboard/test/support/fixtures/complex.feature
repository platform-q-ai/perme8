@authentication
Feature: Complex Authentication
  Multi-scenario feature with rules and outlines.

  Background:
    Given the system is running

  Rule: Password Requirements
    @password
    Scenario: Short password rejected
      Given I am on the registration page
      When I enter a password "ab"
      Then I should see "Password too short"

    Scenario: Valid password accepted
      Given I am on the registration page
      When I enter a password "securepass123"
      Then I should see the success message

  @outline
  Scenario Outline: Login with different roles
    Given I am a "<role>" user
    When I log in
    Then I should see the "<dashboard>" dashboard

    Examples:
      | role  | dashboard |
      | admin | Admin     |
      | user  | User      |
