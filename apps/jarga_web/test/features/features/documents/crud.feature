Feature: Document CRUD Operations
  As a workspace member
  I want to create, update, and delete documents
  So that I can manage my team's documentation

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  # Document Creation

  Scenario: Owner creates a document in workspace
    Given I am logged in as "alice@example.com"
    When I create a document with title "Product Roadmap" in workspace "product-team"
    Then the document should be created successfully
    And the document should have slug "product-roadmap"
    And the document should be owned by "alice@example.com"
    And the document should be private by default
    And the document should have an embedded note component

  Scenario: Admin creates a document in workspace
    Given I am logged in as "bob@example.com"
    When I create a document with title "Architecture Doc" in workspace "product-team"
    Then the document should be created successfully
    And the document should be owned by "bob@example.com"

  Scenario: Member creates a document in workspace
    Given I am logged in as "charlie@example.com"
    When I create a document with title "Meeting Notes" in workspace "product-team"
    Then the document should be created successfully
    And the document should be owned by "charlie@example.com"

  Scenario: Guest cannot create documents
    Given I am logged in as "diana@example.com"
    When I attempt to create a document with title "Unauthorized Doc" in workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Non-member cannot create documents
    Given I am logged in as "eve@example.com"
    When I attempt to create a document with title "Outsider Doc" in workspace "product-team"
    Then I should receive an unauthorized error

  Scenario: Create document with project association
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    When I create a document with title "Mobile Specs" in project "Mobile App"
    Then the document should be created successfully
    And the document should be associated with project "Mobile App"

  Scenario: Cannot create document with project from different workspace
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Marketing Team" and slug "marketing-team"
    And user "alice@example.com" is owner of workspace "marketing-team"
    And a project exists with name "Campaign" in workspace "marketing-team"
    When I attempt to create a document in workspace "product-team" with project from "marketing-team"
    Then I should receive a project not in workspace error

  Scenario: Document slug is unique within workspace
    Given I am logged in as "alice@example.com"
    And a document exists with title "Roadmap" in workspace "product-team"
    When I create a document with title "Roadmap" in workspace "product-team"
    Then the document should be created successfully
    And the document should have a unique slug like "roadmap-*"

  Scenario: Create document without title
    Given I am logged in as "alice@example.com"
    When I attempt to create a document without a title in workspace "product-team"
    Then I should receive a validation error
    And the document should not be created

  Scenario: Document slug handles special characters
    Given I am logged in as "alice@example.com"
    When I create a document with title "Product & Services (2024)" in workspace "product-team"
    Then the document should be created successfully
    And the document slug should be URL-safe

  # Document Updates

  Scenario: Owner updates their own document title
    Given I am logged in as "alice@example.com"
    And a document exists with title "Draft Roadmap" owned by "alice@example.com"
    When I update the document title to "Product Roadmap Q1"
    Then the document title should be "Product Roadmap Q1"
    And the document slug should remain unchanged

  Scenario: Owner changes document visibility to public
    Given I am logged in as "alice@example.com"
    And a private document exists with title "Private Doc" owned by "alice@example.com"
    When I make the document public
    Then the document should be public
    And a visibility changed notification should be broadcast

  Scenario: Owner changes document visibility to private
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I make the document private
    Then the document should be private
    And a visibility changed notification should be broadcast

  Scenario: Member edits public document they don't own
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I update the document title to "Updated Team Doc"
    Then the document title should be "Updated Team Doc"

  Scenario: Member cannot edit private document they don't own
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Alice's Doc" owned by "alice@example.com"
    When I attempt to update the document title to "Hacked"
    Then I should receive a forbidden error

  Scenario: Admin can edit public documents
    Given I am logged in as "bob@example.com"
    And a public document exists with title "Team Guidelines" owned by "charlie@example.com"
    When I update the document title to "Updated Guidelines"
    Then the document title should be "Updated Guidelines"

  Scenario: Admin cannot edit private documents they don't own
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Charlie's Private" owned by "charlie@example.com"
    When I attempt to update the document title to "Admin Override"
    Then I should receive a forbidden error

  Scenario: Guest cannot edit any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to update the document title to "Guest Edit"
    Then I should receive a forbidden error

  Scenario: Update document with empty title
    Given I am logged in as "alice@example.com"
    And a document exists with title "Valid Title" owned by "alice@example.com"
    When I attempt to update the document title to ""
    Then I should receive a validation error
    And the document title should remain "Valid Title"

  # Document Pinning

  Scenario: Owner pins their own document
    Given I am logged in as "alice@example.com"
    And a document exists with title "Important Doc" owned by "alice@example.com"
    When I pin the document
    Then the document should be pinned
    And a pin status changed notification should be broadcast

  Scenario: Owner unpins their own document
    Given I am logged in as "alice@example.com"
    And a pinned document exists with title "Pinned Doc" owned by "alice@example.com"
    When I unpin the document
    Then the document should not be pinned

  Scenario: Member pins public document
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I pin the document
    Then the document should be pinned

  Scenario: Member cannot pin private document they don't own
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Private Doc" owned by "alice@example.com"
    When I attempt to pin the document
    Then I should receive a forbidden error

  Scenario: Guest cannot pin any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to pin the document
    Then I should receive a forbidden error

  # Document Deletion

  Scenario: Owner deletes their own document
    Given I am logged in as "alice@example.com"
    And a document exists with title "Old Doc" owned by "alice@example.com"
    When I delete the document
    Then the document should be deleted successfully
    And the embedded note should also be deleted
    And a document deleted notification should be broadcast

  Scenario: Admin deletes public document
    Given I am logged in as "bob@example.com"
    And a public document exists with title "Outdated Public Doc" owned by "charlie@example.com"
    When I delete the document
    Then the document should be deleted successfully

  Scenario: Admin cannot delete private documents they don't own
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Charlie's Private" owned by "charlie@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  Scenario: Member cannot delete documents they don't own
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  Scenario: Guest cannot delete any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  Scenario: Transaction rollback on note creation failure
    Given I am logged in as "alice@example.com"
    When document creation fails due to note creation error
    Then the document should not be created
    And the database should be in consistent state
