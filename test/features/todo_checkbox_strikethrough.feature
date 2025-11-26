Feature: Todo Checkbox Strikethrough
  As a user
  I want checked todo items to appear with strikethrough text
  So that I can visually distinguish completed items from pending ones

  Scenario: Checking a todo item applies strikethrough
    Given I am on a page with a todo item "Buy groceries"
    And the todo item is unchecked
    When I check the todo checkbox
    Then the text "Buy groceries" should have strikethrough styling

  Scenario: Unchecking a todo item removes strikethrough
    Given I am on a page with a todo item "Buy groceries"
    And the todo item is checked
    And the text "Buy groceries" has strikethrough styling
    When I uncheck the todo checkbox
    Then the text "Buy groceries" should not have strikethrough styling
