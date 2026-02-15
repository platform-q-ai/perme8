@browser
Feature: Todo Checkbox Strikethrough
  As a user
  I want checked todo items to appear with strikethrough text
  So that I can visually distinguish completed items from pending ones

  # Precondition: A document with a todo item exists (seeded)
  # The editor (Milkdown) renders todo/task-list items with checkboxes

  Scenario: Checking a todo item applies strikethrough
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/todo-doc"
    And I wait for the page to load
    And I wait for "#editor-container" to be visible
    And I check "li.task-list-item input[type='checkbox']"
    And I wait for 1 seconds
    Then "li.task-list-item.checked" should exist

  Scenario: Unchecking a todo item removes strikethrough
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/todo-doc-checked"
    And I wait for the page to load
    And I wait for "#editor-container" to be visible
    And I uncheck "li.task-list-item input[type='checkbox']"
    And I wait for 1 seconds
    Then "li.task-list-item.checked" should not exist
