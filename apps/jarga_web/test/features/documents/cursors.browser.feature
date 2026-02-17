@browser
Feature: Multiple Cursors in Collaborative Editor
  As a document collaborator
  I want to see other users' cursors in real-time
  So that I know where my teammates are editing

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com - owner of workspace "product-team" (display: "Alice T.")
  #   bob@example.com   - admin of workspace "product-team" (display: "Bob T.")
  #
  # Seeded documents used in this file:
  #   "Product Spec" - public, by alice (slug: product-spec)
  #
  # Remote cursor DOM structure (from awareness-plugin-factory.ts):
  #   <span class="remote-cursor" data-user-name="Alice T." data-user-id="...">
  #     <span class="remote-cursor-label" style="background-color: #hex">Alice T.</span>
  #   </span>
  #
  # Migrated from: apps/jarga_web/test/wallaby/multiple_cursors_test.exs

  Scenario: User cursors are visible to other users
    # Alice opens the document and types to establish cursor position
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "Hello from Alice" into ".ProseMirror"
    And I wait for 2 seconds
    # Bob opens the same document
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # Bob clicks and types to initialize his own awareness (triggers round-trip)
    When I click ".ProseMirror"
    And I press "End"
    And I wait for 3 seconds
    # Alice updates her cursor position so Bob gets a fresh awareness update
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I press "Home"
    And I wait for 3 seconds
    # Bob should see Alice's cursor label
    When I switch to browser session "bob"
    Then ".remote-cursor[data-user-name='Alice T.']" should exist
    And ".remote-cursor-label" should be visible

  Scenario: Cursor positions update in real-time as users type
    # Both users open the document
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "End"
    And I wait for 2 seconds
    # Alice types on line 1 and triggers awareness update
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "Line 1" into ".ProseMirror"
    And I press "Home"
    And I wait for 3 seconds
    # Bob sees Alice's cursor
    When I switch to browser session "bob"
    Then ".remote-cursor[data-user-name='Alice T.']" should exist
    # Alice moves cursor to line 2
    When I switch to browser session "alice"
    And I press "End"
    And I press "Enter"
    And I type "Line 2" into ".ProseMirror"
    And I press "Home"
    And I wait for 3 seconds
    # Bob still sees Alice's cursor (now at updated position)
    When I switch to browser session "bob"
    Then ".remote-cursor[data-user-name='Alice T.']" should exist
    And ".ProseMirror" should contain text "Line 2"

  Scenario: Cursor disappears when user disconnects
    # Both users open the document
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "End"
    And I wait for 2 seconds
    # Alice types to establish cursor and trigger awareness broadcast
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "Alice is here" into ".ProseMirror"
    And I press "Home"
    And I wait for 3 seconds
    # Bob sees Alice's cursor
    When I switch to browser session "bob"
    Then ".remote-cursor[data-user-name='Alice T.']" should exist
    # Alice navigates away (disconnects from the document)
    When I switch to browser session "alice"
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # Bob should no longer see Alice's cursor after awareness cleanup.
    # The awareness adapter broadcasts a removal when the client navigates away.
    When I switch to browser session "bob"
    And I wait for 5 seconds
    Then ".remote-cursor[data-user-name='Alice T.']" should not exist

  Scenario: Multiple users see each other's cursors simultaneously
    # Both users open the document
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "End"
    And I wait for 2 seconds
    # Alice types her content and moves cursor to trigger awareness
    When I switch to browser session "alice"
    And I type "Alice is typing" into ".ProseMirror"
    And I press "Home"
    And I wait for 2 seconds
    # Bob types his content and moves cursor to trigger awareness
    When I switch to browser session "bob"
    And I press "End"
    And I press "Enter"
    And I type "Bob is also typing" into ".ProseMirror"
    And I press "Home"
    And I wait for 3 seconds
    # Bob sees Alice's cursor
    Then ".remote-cursor[data-user-name='Alice T.']" should exist
    # Alice triggers awareness refresh by moving cursor, then checks for Bob
    When I switch to browser session "alice"
    And I press "End"
    And I wait for 3 seconds
    Then ".remote-cursor[data-user-name='Bob T.']" should exist
