@browser @wip
Feature: Agent Discovery
  As a user
  I want to find and filter available agents
  So that I can use the right AI assistant for my task

  # Seed data: A test user with email "test@example.com" and password "Password123!"
  # must exist. Workspace memberships and agents are assumed to be seeded.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "[data-testid='email']" with "test@example.com"
    And I fill "[data-testid='password']" with "Password123!"
    And I click the "Log in" button
    And I wait for network idle

  # Viewing Agents in Workspace

  Scenario: View available agents in workspace context
    # Prerequisite: user is a member of workspace "Dev Team" with agents seeded:
    # "Team Assistant" (shared, Alice), "Code Reviewer" (shared, Bob), "My Helper" (private, me)
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for network idle
    Then I should see "Team Assistant"
    And I should see "Code Reviewer"
    And I should see "My Helper"
    And there should be 3 "[data-testid='agent-card']" elements

  Scenario: Workspace members can only see enabled agents
    # NOTE: Multi-user scenario. From our browser, we verify that disabled agents
    # are not shown in the workspace agent list.
    # Prerequisite: "Active Helper" (enabled) and "Disabled Bot" (disabled) both in "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for network idle
    Then I should see "Active Helper"
    And I should not see "Disabled Bot"

  Scenario: Filter agents by workspace membership
    # Prerequisite: user is a member of "Dev Team" (with "Dev Helper") and "QA Team" (with "QA Bot")
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for network idle
    Then I should see "Dev Helper"
    And I should not see "QA Bot"

  # Agent Visibility

  Scenario: Agent visibility controls discoverability
    # NOTE: Multi-user scenario. We can only verify from our own session that
    # private agents from other users are not visible.
    When I navigate to "${baseUrl}/agents"
    And I wait for network idle
    Then I should not see "Secret Helper"

  Scenario: Shared agents are discoverable in workspaces
    # Prerequisite: "Public Helper" (shared) is added to workspace "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for network idle
    Then I should see "Public Helper"

  Scenario: Disabled agent is hidden from workspace members
    # Prerequisite: "Team Helper" is in workspace "Dev Team" and is disabled
    # NOTE: Multi-user visibility is tested server-side; here we verify our own view.
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for network idle
    Then I should not see "Team Helper"

  # Viewable Agents List

  Scenario: List viewable agents shows own agents and all shared agents
    # Prerequisite: user has private agents "My Bot 1" and "My Bot 2";
    # other users have shared agents "Public Helper" and "Code Reviewer"
    When I navigate to "${baseUrl}/agents"
    And I wait for network idle
    Then I should see "My Bot 1"
    And I should see "My Bot 2"
    And I should see "Public Helper"
    And I should see "Code Reviewer"

  Scenario: Viewable agents ordered by most recent first
    # Prerequisite: agents seeded with creation dates:
    # "Agent C" (1 day ago), "Agent B" (2 days ago), "Agent A" (3 days ago)
    When I navigate to "${baseUrl}/agents"
    And I wait for network idle
    And I store the text of "[data-testid='agent-card']:nth-child(1) [data-testid='agent-name']" as "first"
    And I store the text of "[data-testid='agent-card']:nth-child(2) [data-testid='agent-name']" as "second"
    And I store the text of "[data-testid='agent-card']:nth-child(3) [data-testid='agent-name']" as "third"
    Then the variable "first" should contain "Agent C"
    And the variable "second" should contain "Agent B"
    And the variable "third" should contain "Agent A"

  # Agent System Prompts in Chat

  Scenario: Agent system prompt is used in chat
    # NOTE: LLM response content is non-deterministic and cannot be asserted
    # in a browser test. We verify the agent can be selected and a message sent.
    # Prerequisite: agent "Math Tutor" with system prompt exists
    When I navigate to "${baseUrl}/chat"
    And I wait for network idle
    And I click "[data-testid='agent-selector']"
    And I click "[data-testid='agent-option-Math Tutor']"
    And I fill "[data-testid='chat-input']" with "What is calculus?"
    And I click the "Send" button
    And I wait for "[data-testid='chat-response']" to be visible
    Then "[data-testid='chat-response']" should be visible

  Scenario: Agent system prompt combines with document context
    # NOTE: This scenario tests internal LLM message composition which is not
    # directly observable in the browser. We verify the chat UI works with
    # an agent selected while viewing a document.
    # Prerequisite: a document and agent "Analyzer" must exist
    When I navigate to "${baseUrl}/documents"
    And I wait for network idle
    And I click "[data-testid='document-link']"
    And I wait for network idle
    And I click "[data-testid='agent-selector']"
    And I click "[data-testid='agent-option-Analyzer']"
    And I fill "[data-testid='chat-input']" with "What are the requirements?"
    And I click the "Send" button
    And I wait for "[data-testid='chat-response']" to be visible
    Then "[data-testid='chat-response']" should be visible
