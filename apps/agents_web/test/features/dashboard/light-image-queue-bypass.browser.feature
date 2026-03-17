@browser @sessions @images
Feature: Lightweight Container Image Selection and Queue Bypass
  As a developer using the sessions UI
  I want to select a lightweight discussion-only container image
  So that ticket triage and planning work starts instantly without consuming heavyweight build resources

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Image picker shows available container images
    Given I navigate to "${baseUrl}/sessions?fixture=image_picker"
    And I wait for network idle
    Then "[data-testid='image-picker']" should exist

  Scenario: Light image tasks bypass the queue
    Given I navigate to "${baseUrl}/sessions?fixture=light_image_bypass"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist

  Scenario: Session card displays the selected image label
    Given I navigate to "${baseUrl}/sessions?fixture=light_image_running"
    And I wait for network idle
    Then "[data-testid='session-image']" should exist
