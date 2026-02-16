@browser @chat @editor
Feature: Chat Editor Integration
  As a user
  I want to invoke AI agents directly from the document editor
  So that I can get AI assistance without leaving my editing context

  # Browser adapter translation of editor.feature
  # Tests editor integration through the browser UI:
  # - @j command for inline agent queries
  # - Agent response rendering in editor
  #
  # NOTE: Many scenarios from the source file are tagged @ignore because they
  # require complex Milkdown editor interactions. Only non-ignored scenarios
  # are translated here.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Execute agent query with @j command
    # Navigate to a document in a workspace
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I wait for "[data-test-editor]" to be visible
    And I click "[data-test-editor]"
    And I type "@j ${agentSlug} How do I write a test?" into "[data-test-editor]"
    And I press "Enter"
    And I wait for 5 seconds
    Then "[data-test-editor]" should be visible

  Scenario: Agent query uses document content as context
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I wait for "[data-test-editor]" to be visible
    And I click "[data-test-editor]"
    And I type "@j ${agentSlug} What features are described?" into "[data-test-editor]"
    And I press "Enter"
    And I wait for 5 seconds
    Then "[data-test-editor]" should be visible

  Scenario: Valid agent invocation with response
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I wait for "[data-test-editor]" to be visible
    And I click "[data-test-editor]"
    And I type "@j ${agentSlug} What is a PRD?" into "[data-test-editor]"
    And I press "Enter"
    And I wait for 5 seconds
    Then "[data-test-editor]" should be visible

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Insert button only visible on document pages
    # On dashboard - no insert buttons
    Given I am on "${baseUrl}/dashboard"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-insert-button]" should not exist
    # On document page - insert buttons available
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Give me a suggestion"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-insert-button]" should exist
