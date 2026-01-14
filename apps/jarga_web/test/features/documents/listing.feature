Feature: Document Listing
  As a workspace member
  I want to see documents filtered by visibility and project
  So that I can find the documents I need

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  Scenario: User sees their own documents and public documents
    Given I am logged in as "charlie@example.com"
    And the following documents exist in workspace "product-team":
      | title              | owner              | visibility |
      | Charlie's Private  | charlie@example.com | private   |
      | Alice's Private    | alice@example.com  | private   |
      | Alice's Public     | alice@example.com  | public    |
      | Bob's Public       | bob@example.com    | public    |
    When I list documents in workspace "product-team"
    Then I should see documents:
      | title              |
      | Charlie's Private  |
      | Alice's Public     |
      | Bob's Public       |
    And I should not see documents:
      | title              |
      | Alice's Private    |

  Scenario: Workspace page shows only workspace-level documents (not project documents)
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a document exists with title "Workspace Doc" in workspace "product-team"
    And a document exists with title "Project Doc" in project "Mobile App"
    When I list documents in workspace "product-team"
    Then I should see documents:
      | title           |
      | Workspace Doc   |
    And I should not see "Project Doc"

  Scenario: List documents filtered by project
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a project exists with name "Web App" in workspace "product-team"
    And the following documents exist:
      | title           | project     |
      | Mobile Specs    | Mobile App  |
      | Mobile Design   | Mobile App  |
      | Web Architecture| Web App     |
    When I list documents for project "Mobile App"
    Then I should see documents:
      | title           |
      | Mobile Specs    |
      | Mobile Design   |
    And I should not see "Web Architecture"
