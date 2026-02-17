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
  # @wip: Scenarios require typing into ProseMirror contenteditable and
  # clicking at precise coordinates within task list items. The current
  # exo-bdd browser adapter does not yet have step definitions for rich
  # editor interaction or coordinate-based clicking.
  #
  # Multi-user scenarios additionally require two simultaneous browser sessions.
  #
  # Migrated from: apps/jarga_web/test/wallaby/gfm_checkbox_test.exs

  @wip
  Scenario: User can insert a checkbox via markdown
    # Wallaby: "user can insert a checkbox via markdown"
    # Type "- [ ] Task item"; verify li[data-item-type='task'] appears
    # with data-checked="false" and visible task text.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "- [ ] Task item" in .ProseMirror
    # TODO: Assert li[data-item-type='task'][data-checked='false'] exists
    # TODO: Assert task text "Task item" is visible

  @wip
  Scenario: User can check a checkbox by clicking
    # Wallaby: "user can check a checkbox by clicking"
    # Type checkbox markdown, then click on the checkbox area (left side
    # of the task list item, not the paragraph text); verify
    # data-checked changes from "false" to "true".
    # Note: Requires coordinate-based click (15px from left edge of li).
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "- [ ] Task item" in .ProseMirror
    # TODO: Click checkbox area (left side of task li element)
    # TODO: Assert li[data-item-type='task'][data-checked='true'] exists

  @wip
  Scenario: Clicking checkbox toggles state but clicking text does not
    # Wallaby: "clicking checkbox toggles state, clicking text does not"
    # Regression test: create a checked checkbox ("- [x] Task item"),
    # click on the checkbox area to uncheck it, then click on the
    # paragraph text area — state should NOT toggle back.
    # This validates the fix that prevents text clicks from toggling checkboxes.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "- [x] Task item" (initially checked)
    # TODO: Assert data-checked='true'
    # TODO: Click checkbox area (left side) to toggle — assert data-checked='false'
    # TODO: Click paragraph text area (80px from left) — assert data-checked='false' (unchanged)

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

  @wip
  Scenario: Multiple checkboxes maintain independent state
    # Wallaby: "multiple checkboxes maintain independent state"
    # Create 3 checkboxes, check only the second one;
    # verify exactly 1 checked and 2 unchecked.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type 3 task items: "- [ ] Task 1", Enter, "- [ ] Task 2", Enter, "- [ ] Task 3"
    # TODO: Assert 3 li[data-item-type='task'][data-checked='false']
    # TODO: Click the second task item's checkbox area
    # TODO: Assert 1 li[data-checked='true'] and 2 li[data-checked='false']
