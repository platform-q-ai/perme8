@browser
Feature: GFM Checkboxes in Editor
  As a document author
  I want to use GitHub-flavored markdown checkboxes in the editor
  So that I can create interactive task lists within documents

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com - owner of workspace "product-team"
  #   bob@example.com   - admin of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec" - public, by alice (slug: product-spec)
  #
  # The Milkdown GFM preset converts "- [ ] " into a task list item with
  # data-item-type="task" and data-checked="false" attributes on the <li>.
  # Clicking the checkbox area (left side of <li>, not the text <p>) toggles state.
  #
  # Multi-user scenarios additionally require two simultaneous browser sessions.
  #
  # Migrated from: apps/jarga_web/test/wallaby/gfm_checkbox_test.exs

  Scenario: User can insert a checkbox via markdown
    # Wallaby: "user can insert a checkbox via markdown"
    Given I am on "${baseUrl}/users/log-in"
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
    And I type "- [ ] Task item" into ".ProseMirror"
    Then "li[data-item-type='task']" should exist
    And "li[data-item-type='task']" should have attribute "data-checked" with value "false"
    And I should see "Task item"

  Scenario: User can check a checkbox by clicking
    # Wallaby: "user can check a checkbox by clicking"
    Given I am on "${baseUrl}/users/log-in"
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
    And I type "- [ ] Task item" into ".ProseMirror"
    Then "li[data-item-type='task']" should have attribute "data-checked" with value "false"
    # Click on the checkbox area (left side of li, position 5,5 = checkbox zone)
    When I click "li[data-item-type='task']" at position 5,5
    Then "li[data-item-type='task']" should have attribute "data-checked" with value "true"

  Scenario: Clicking checkbox toggles state but clicking text does not
    # Wallaby: "clicking checkbox toggles state, clicking text does not"
    Given I am on "${baseUrl}/users/log-in"
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
    # Create a checked checkbox
    And I type "- [x] Task item" into ".ProseMirror"
    Then "li[data-item-type='task']" should have attribute "data-checked" with value "true"
    # Click checkbox area to uncheck
    When I click "li[data-item-type='task']" at position 5,5
    Then "li[data-item-type='task']" should have attribute "data-checked" with value "false"
    # Click text area - should NOT toggle back
    When I click "li[data-item-type='task'] p"
    Then "li[data-item-type='task']" should have attribute "data-checked" with value "false"

  @wip
  Scenario: Checkbox state syncs between users
    # Wallaby: "checkbox state syncs between users"
    # Multi-user: User A creates a checkbox, User B sees it unchecked.
    # User A checks it; both users see it checked.
    # Requires two simultaneous browser sessions.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A types "- [ ] Task item"
    # TODO (multi-browser): User B sees li[data-item-type='task'][data-checked='false']
    # TODO (multi-browser): User A clicks checkbox area
    # TODO (multi-browser): Both users see data-checked='true'

  Scenario: Multiple checkboxes maintain independent state
    # Wallaby: "multiple checkboxes maintain independent state"
    Given I am on "${baseUrl}/users/log-in"
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
    And I type "- [ ] Task 1" into ".ProseMirror"
    And I press "Enter"
    And I type "Task 2" into ".ProseMirror"
    And I press "Enter"
    And I type "Task 3" into ".ProseMirror"
    Then there should be 3 "li[data-item-type='task']" elements
    # Check only the second checkbox (nth-child(2))
    When I click "li[data-item-type='task']:nth-child(2)" at position 5,5
    Then there should be 1 "li[data-item-type='task'][data-checked='true']" elements
    And there should be 2 "li[data-item-type='task'][data-checked='false']" elements
