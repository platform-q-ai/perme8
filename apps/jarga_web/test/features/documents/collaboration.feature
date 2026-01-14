Feature: Document Collaboration
  As a workspace member
  I want to collaborate on documents in real-time
  So that my team can work together efficiently

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  # Collaborative Editing

  @javascript
  Scenario: Multiple users edit document simultaneously
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Collaborative Doc" owned by "alice@example.com"
    And user "charlie@example.com" is also viewing the document
    When I make changes to the document content
    Then user "charlie@example.com" should see my changes in real-time via PubSub
    And the changes should be synced using Yjs CRDT

  @javascript
  Scenario: User saves document content
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Notes" owned by "alice@example.com"
    When I edit the document content
    Then the changes should be broadcast immediately to other users
    And the changes should be debounced before saving to database
    And the Yjs state should be persisted

  @javascript
  Scenario: User force saves on tab close
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    And I have unsaved changes
    When I close the browser tab
    Then the changes should be force saved immediately
    And the Yjs state should be updated

  # Real-time Notifications

  Scenario: Document title change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the document
    When I update the document title to "Updated Team Doc"
    Then user "charlie@example.com" should receive a real-time title update
    And the title should update in their UI without refresh

  Scenario: Document visibility change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Shared Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the document
    When I make the document private
    Then user "charlie@example.com" should receive a visibility changed notification
    And user "charlie@example.com" should lose access to the document

  Scenario: Document pin status change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Important Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the workspace
    When I pin the document
    Then user "charlie@example.com" should see the document marked as pinned
