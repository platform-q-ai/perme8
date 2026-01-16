Feature: Document Components
  As a workspace member
  I want documents to have embedded components
  So that I can structure content within documents

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  Scenario: Document has embedded note component by default
    Given I am logged in as "alice@example.com"
    When I create a document with title "New Doc" in workspace "product-team"
    Then the document should have one note component
    And the note component should be at position 0
    And the note component type should be "note"

  Scenario: Access document's embedded note
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    When I retrieve the document's note component
    Then I should receive the associated Note record
    And the note should be editable

  Scenario: Document inherits project from note
    Given I am logged in as "alice@example.com"
    And a project exists with name "Research" in workspace "product-team"
    When I create a document with title "Research Doc" in project "Research"
    Then the document should be associated with project "Research"
    And the embedded note should also be associated with project "Research"
