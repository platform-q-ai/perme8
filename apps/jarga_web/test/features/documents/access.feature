Feature: Document Access Control
  As a workspace member
  I want document visibility and permissions to be enforced
  So that private documents remain confidential

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  # Document Viewing

  Scenario: Owner views their own private document
    Given I am logged in as "alice@example.com"
    And a private document exists with title "Private Notes" owned by "alice@example.com"
    When I view document "Private Notes" in workspace "product-team"
    Then I should see the document content
    And I should be able to edit the document

  Scenario: Member cannot view another user's private document
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Alice's Private Notes" owned by "alice@example.com"
    When I attempt to view document "Alice's Private Notes" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Admin cannot view another user's private document
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Alice's Private Notes" owned by "alice@example.com"
    When I attempt to view document "Alice's Private Notes" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Member views public document created by another user
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I view document "Team Guidelines" in workspace "product-team"
    Then I should see the document content
    And I should be able to edit the document

  Scenario: Guest views public document in read-only mode
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I view document "Team Guidelines" in workspace "product-team"
    Then I should see the document content
    And I should see a read-only indicator
    And I should not be able to edit the document

  Scenario: Guest cannot view private documents
    Given I am logged in as "diana@example.com"
    And a private document exists with title "Private Roadmap" owned by "alice@example.com"
    When I attempt to view document "Private Roadmap" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Non-member cannot view any documents
    Given I am logged in as "eve@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I attempt to view document "Team Guidelines" in workspace "product-team"
    Then I should receive an unauthorized error

  # Breadcrumb Navigation

  Scenario: Breadcrumb navigation in document view
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a document exists with title "Specs" in project "Mobile App"
    When I view the document
    Then I should see breadcrumbs showing "Product Team > Mobile App > Specs"

  Scenario: Workspace name updates in document view
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    And I am viewing the document
    When user "alice@example.com" updates workspace name to "Engineering Team"
    Then I should see the workspace name updated to "Engineering Team" in breadcrumbs

  Scenario: Project name updates in document view
    Given I am logged in as "alice@example.com"
    And a project exists with name "App" in workspace "product-team"
    And a document exists with title "Specs" in project "App"
    And I am viewing the document
    When user "alice@example.com" updates project name to "Mobile Application"
    Then I should see the project name updated to "Mobile Application" in breadcrumbs
