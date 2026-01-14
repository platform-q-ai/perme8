Feature: Agent Discovery
  As a user
  I want to find and filter available agents
  So that I can use the right AI assistant for my task

  Background:
    Given I am logged in as a user

  # Viewing Agents in Workspace

  Scenario: View available agents in workspace context
    Given I am a member of workspace "Dev Team"
    And workspace "Dev Team" has the following agents:
      | Agent Name      | Owner  | Visibility |
      | Team Assistant  | Alice  | SHARED     |
      | Code Reviewer   | Bob    | SHARED     |
      | My Helper       | Me     | PRIVATE    |
    When I view agents in workspace "Dev Team" context
    Then I should see "Team Assistant"
    And I should see "Code Reviewer"
    And I should see "My Helper"
    And I should see 3 agents total

  Scenario: Workspace members can only see enabled agents
    Given I am a member of workspace "Dev Team"
    And I have two agents:
      | Agent Name     | Enabled |
      | Active Helper  | true    |
      | Disabled Bot   | false   |
    And both agents are added to workspace "Dev Team"
    When another workspace member views available agents
    Then they should see "Active Helper"
    And they should not see "Disabled Bot"

  Scenario: Filter agents by workspace membership
    Given I am a member of workspaces "Dev Team" and "QA Team"
    And workspace "Dev Team" has agent "Dev Helper"
    And workspace "QA Team" has agent "QA Bot"
    When I view agents in workspace "Dev Team" context
    Then I should see "Dev Helper"
    And I should not see "QA Bot"

  # Agent Visibility

  Scenario: Agent visibility controls discoverability
    Given I have a private agent named "Secret Helper"
    And another user is "Bob"
    When "Bob" searches for available agents
    Then "Bob" should not see "Secret Helper"

  Scenario: Shared agents are discoverable in workspaces
    Given I have a shared agent named "Public Helper"
    And "Public Helper" is added to workspace "Dev Team"
    And "Bob" is a member of workspace "Dev Team"
    When "Bob" views agents in workspace "Dev Team"
    Then "Bob" should see "Public Helper"
    And "Bob" should be able to clone "Public Helper"

  Scenario: Disabled agent is hidden from workspace members
    Given I have an agent "Team Helper" in workspace "Dev Team"
    And "Team Helper" is enabled
    And workspace member "Bob" can see "Team Helper"
    When I disable agent "Team Helper"
    Then "Bob" should no longer see "Team Helper" in the workspace agents list
    And "Bob" cannot select "Team Helper" in the chat panel

  # Viewable Agents List

  Scenario: List viewable agents shows own agents and all shared agents
    Given I have private agents "My Bot 1" and "My Bot 2"
    And user "Alice" has shared agent "Public Helper"
    And user "Bob" has shared agent "Code Reviewer"
    When I list viewable agents
    Then the viewable agents should include "My Bot 1"
    And the viewable agents should include "My Bot 2"
    And the viewable agents should include "Public Helper"
    And the viewable agents should include "Code Reviewer"
    And I should not see Alice's private agents
    And I should not see Bob's private agents

  Scenario: Viewable agents ordered by most recent first
    Given I created agent "Agent A" 3 days ago
    And Alice created shared agent "Agent B" 2 days ago
    And I created agent "Agent C" 1 day ago
    When I list viewable agents
    Then the agents should be ordered: "Agent C", "Agent B", "Agent A"

  # Agent System Prompts in Chat

  Scenario: Agent system prompt is used in chat
    Given I have an agent named "Math Tutor" with system prompt "You are a patient math teacher"
    And "Math Tutor" is selected in the chat panel
    When I send a message "What is calculus?"
    Then the LLM should receive the system message "You are a patient math teacher"
    And the response should reflect the math tutor persona

  Scenario: Agent system prompt combines with document context
    Given I am viewing a document with content "Product specs for Widget X"
    And I have an agent named "Analyzer" with system prompt "Analyze requirements"
    And "Analyzer" is selected in the chat panel
    When I send a message "What are the requirements?"
    Then the system message should include the agent's prompt
    And the system message should include the document content as context
