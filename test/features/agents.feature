Feature: Agent Managemen
  As a user
  I want to create, manage, and share AI agents
  So that I can customize my AI assistant experiences across workspaces

  Background:
    Given I am logged in as a user

  # Agent Creation
  Scenario: Create a new personal agent with default settings
    When I navigate to the agents page
    And I click "New Agent"
    And I fill in the agent name as "My Assistant"
    And I submit the agent form
    Then I should see "My Assistant" in my agents list
    And the agent should have visibility "PRIVATE"
    And the agent should have temperature 0.7
    And the agent should be enabled

  Scenario: Create an agent with custom configuration
    When I navigate to the agents page
    And I click "New Agent"
    And I fill in the following agent details:
      | Field          | Value                                |
      | Name           | Code Reviewer                        |
      | Description    | Reviews code for best practices      |
      | System Prompt  | You are an expert code reviewer.     |
      | Model          | gpt-4-turbo                          |
      | Temperature    | 0.3                                  |
      | Visibility     | SHARED                               |
    And I submit the agent form
    Then I should see "Code Reviewer" in my agents list
    And the agent "Code Reviewer" should have model "gpt-4-turbo"
    And the agent "Code Reviewer" should have temperature 0.3
    And the agent "Code Reviewer" should have visibility "SHARED"

  Scenario: Create agent with invalid temperature
    When I navigate to the agents page
    And I click "New Agent"
    And I fill in the agent name as "Test Agent"
    And I set the temperature to "2.5"
    And I submit the agent form
    Then I should see a validation error "must be less than or equal to 2"
    And the agent should not be created

  Scenario: Create agent without required name
    When I navigate to the agents page
    And I click "New Agent"
    And I submit the agent form without filling in the name
    Then I should see a validation error "can't be blank"
    And the agent should not be created

  # Agent Listing
  Scenario: View my personal agents list
    Given I have created the following agents:
      | Name              | Model      | Visibility |
      | Assistant One     | gpt-4-turbo| PRIVATE    |
      | Code Helper       | gpt-mini   | SHARED     |
      | Documentation Bot | gpt-4-turbo| PRIVATE    |
    When I navigate to the agents page
    Then I should see 3 agents in my list
    And I should see "Assistant One" with model "gpt-4-turbo"
    And I should see "Code Helper" with model "gpt-mini"
    And I should see "Documentation Bot" with model "gpt-4-turbo"

  Scenario: Empty agents list shows prompt to create first agent
    Given I have no agents
    When I navigate to the agents page
    Then I should see "No agents yet"
    And I should see "Create your first agent to get started"
    And I should see a "Create Agent" button

  # Agent Updates
  Scenario: Update agent configuration
    Given I have an agent named "My Assistant"
    When I navigate to the agents page
    And I click edit on "My Assistant"
    And I change the system prompt to "You are a helpful coding assistant"
    And I change the model to "gpt-4-turbo"
    And I submit the agent form
    Then the agent "My Assistant" should have the updated system prompt
    And the agent "My Assistant" should have model "gpt-4-turbo"

  Scenario: Update agent visibility from PRIVATE to SHARED
    Given I have an agent named "Personal Assistant" with visibility "PRIVATE"
    When I navigate to the agents page
    And I click edit on "Personal Assistant"
    And I change the visibility to "SHARED"
    And I submit the agent form
    Then the agent "Personal Assistant" should have visibility "SHARED"
    And other workspace members should be able to see the agent

  Scenario: Update agent and notify affected workspaces
    Given I have an agent named "Team Assistant" added to workspaces:
      | Workspace Name |
      | Dev Team       |
      | QA Team        |
    When I update the agent "Team Assistant" with a new system prompt
    Then workspace "Dev Team" members should see the updated agent
    And workspace "QA Team" members should see the updated agent
    And the chat panel in both workspaces should reflect the changes

  Scenario: Cannot update another user's agent
    Given another user has created an agent named "Their Agent"
    When I attempt to edit "Their Agent"
    Then I should see an error "not_found"
    And the agent should not be modified

  # Agent Deletion
  Scenario: Delete an agent
    Given I have an agent named "Old Assistant"
    When I navigate to the agents page
    And I click delete on "Old Assistant"
    And I confirm the deletion
    Then "Old Assistant" should not appear in my agents list

  Scenario: Delete agent removes it from all workspaces
    Given I have an agent named "Shared Helper" added to workspaces:
      | Workspace Name |
      | Project A      |
      | Project B      |
    When I delete the agent "Shared Helper"
    Then the agent should be removed from workspace "Project A"
    And the agent should be removed from workspace "Project B"
    And workspace members should receive notifications of the removal

  Scenario: Cannot delete another user's agent
    Given another user has created an agent named "Their Agent"
    When I attempt to delete "Their Agent"
    Then I should see an error "not_found"
    And the agent should still exist

  # Agent Workspace Assignment
  Scenario: Add my private agent to a workspace I belong to
    Given I have a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And I have a private agent named "Code Helper"
    When I navigate to workspace "Dev Team" settings
    And I add agent "Code Helper" to the workspace
    Then "Code Helper" should appear in the workspace agents list
    And other workspace members should not see "Code Helper" because it's PRIVATE

  Scenario: Add my shared agent to a workspace
    Given I have a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And I have a shared agent named "Team Assistant"
    When I navigate to workspace "Dev Team" settings
    And I add agent "Team Assistant" to the workspace
    Then "Team Assistant" should appear in the workspace agents list
    And all workspace members should be able to use "Team Assistant"

  Scenario: Cannot add agent to workspace I'm not a member of
    Given there is a workspace named "Other Team"
    And I am not a member of workspace "Other Team"
    And I have an agent named "My Assistant"
    When I attempt to add "My Assistant" to workspace "Other Team"
    Then the sync should succeed
    But the agent should not be added to the workspace

  Scenario: Cannot add another user's agent to a workspace
    Given I am a member of workspace "Dev Team"
    And another user has created an agent named "Their Agent"
    When I attempt to add "Their Agent" to workspace "Dev Team"
    Then I should see an error "not_found"
    And the agent should not be added to the workspace

  Scenario: Remove agent from workspace
    Given I have an agent named "Code Helper"
    And "Code Helper" is added to workspace "Dev Team"
    And I am a member of workspace "Dev Team"
    When I navigate to workspace "Dev Team" settings
    And I remove agent "Code Helper" from the workspace
    Then "Code Helper" should not appear in workspace agents list
    And workspace members should receive notification of removal

  # Agent Cloning
  Scenario: Clone my own agent
    Given I have an agent named "Original Assistant" with:
      | System Prompt | You are helpful |
      | Model         | gpt-4-turbo     |
      | Temperature   | 0.7             |
      | Visibility    | PRIVATE         |
    When I clone the agent "Original Assistant"
    Then a new agent "Original Assistant (Copy)" should be created
    And the cloned agent should have the same system prompt
    And the cloned agent should have the same model
    And the cloned agent should have the same temperature
    And the cloned agent should have visibility "PRIVATE"
    And the cloned agent should belong to me
    And the cloned agent should not be added to any workspaces

  Scenario: Clone a shared agent from workspace context
    Given there is a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And another user has a shared agent named "Team Helper" in the workspace
    When I clone "Team Helper" from the workspace context
    Then a new agent "Team Helper (Copy)" should be created
    And the cloned agent should belong to me
    And the cloned agent should have visibility "PRIVATE"
    And the cloned agent should not be in any workspaces

  Scenario: Cannot clone agent without workspace context if not owner
    Given another user has a shared agent named "Public Helper"
    And I am not in a workspace with "Public Helper"
    When I attempt to clone "Public Helper" without workspace context
    Then I should see an error "forbidden"
    And the agent should not be cloned

  Scenario: Cannot clone private agent that's not mine
    Given another user has a private agent named "Private Helper"
    When I attempt to clone "Private Helper"
    Then I should see an error "forbidden"
    And the agent should not be cloned

  # Agent Discovery
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

  # Agent Policies
  Scenario: Only owner can edit agent
    Given I have an agent named "My Assistant"
    And another user is "Bob"
    When "Bob" attempts to edit "My Assistant"
    Then "Bob" should see an error "not_found"
    And the agent should not be modified

  Scenario: Only owner can delete agent
    Given I have an agent named "My Assistant"
    And another user is "Bob"
    When "Bob" attempts to delete "My Assistant"
    Then "Bob" should see an error "not_found"
    And the agent should still exist

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

  # Agent Selection and Persistence
  Scenario: Select agent for workspace persists in user preferences
    Given I am in workspace "Dev Team"
    And workspace has agents "Helper A" and "Helper B"
    When I select agent "Helper A" in the chat panel
    Then my selection should be saved to user preferences
    And when I return to workspace "Dev Team" later, "Helper A" should still be selected

  Scenario: Different agent selection per workspace
    Given I am a member of workspaces "Dev Team" and "QA Team"
    When I select agent "Dev Helper" in workspace "Dev Team"
    And I navigate to workspace "QA Team"
    And I select agent "QA Bot" in workspace "QA Team"
    Then workspace "Dev Team" should remember "Dev Helper" as my selection
    And workspace "QA Team" should remember "QA Bot" as my selection

  Scenario: Auto-select first agent when no preference exists
    Given I am in workspace "Dev Team"
    And workspace has agents "Alpha", "Beta", "Gamma"
    And I have no saved agent preference for this workspace
    When I open the chat panel
    Then agent "Alpha" should be auto-selected
    And the selection should be saved to my preferences

  # Agent Cost Tracking
  Scenario: Configure token costs for agent
    When I create an agent with:
      | Field                       | Value  |
      | Name                        | GPT-4  |
      | Input Token Cost            | 0.03   |
      | Cached Input Token Cost     | 0.01   |
      | Output Token Cost           | 0.06   |
      | Cached Output Token Cost    | 0.02   |
    Then the agent should have the configured token costs
    And future usage tracking should use these costs

  # Agent System Prompts
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

  # Real-time Updates via PubSub
  Scenario: Agent updates propagate to all connected clients
    Given I have an agent "Team Bot" in workspace "Dev Team"
    And "Alice" is viewing workspace "Dev Team" chat panel
    And "Bob" is viewing workspace "Dev Team" chat panel
    When I update agent "Team Bot" configuration
    Then "Alice" should see the updated agent in her chat panel
    And "Bob" should see the updated agent in his chat panel

  Scenario: Agent deletion removes it from connected clients
    Given I have an agent "Old Bot" in workspace "Dev Team"
    And "Alice" has "Old Bot" selected in the chat panel
    When I delete agent "Old Bot"
    Then "Alice" should see "Old Bot" removed from the agent list
    And if "Old Bot" was her only agent, the chat panel should auto-select another agent

  # Edge Cases
  Scenario: Handle agent not found gracefully
    Given I have an agent with ID "abc-123"
    When the agent is deleted by another process
    And I attempt to load the agent
    Then I should receive an error "not_found"

  Scenario: Duplicate agent names are allowed
    When I create an agent named "Helper"
    And I create another agent named "Helper"
    Then both agents should exist
    And both should have unique IDs

  Scenario: Agent with empty model uses system default
    Given I create an agent without specifying a model
    When I use the agent in chat
    Then the system should use the default LLM model

  Scenario: Agent temperature outside range is rejected
    When I attempt to create an agent with temperature "-0.1"
    Then I should see a validation error
    When I attempt to create an agent with temperature "2.1"
    Then I should see a validation error

  Scenario: Disabled agent is hidden from workspace members
    Given I have an agent "Team Helper" in workspace "Dev Team"
    And "Team Helper" is enabled
    And workspace member "Bob" can see "Team Helper"
    When I disable agent "Team Helper"
    Then "Bob" should no longer see "Team Helper" in the workspace agents list
    And "Bob" cannot select "Team Helper" in the chat panel

  # Agent Discovery and Listing
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

  # Agent Parameter Validation
  Scenario: Validate agent parameters before saving
    Given I am creating a new agent
    When I submit parameters with temperature "1.5"
    Then the parameters should be validated
    And the validation should pass
    And temperature should be converted to float 1.5

  Scenario: Validation rejects invalid temperature
    Given I am creating a new agent
    When I submit parameters with temperature "invalid"
    Then the validation should fail
    And I should see a changeset error
    And the agent should not be created

  Scenario: Validation rejects temperature out of range
    Given I am creating a new agent
    When I submit parameters with temperature "2.5"
    Then the validation should fail
    And I should see error "must be less than or equal to 2"

  Scenario: Validation handles missing required fields
    Given I am creating a new agent
    When I submit parameters without a name
    Then the validation should fail
    And I should see error "can't be blank"

  # Agent Workspace Synchronization
  Scenario: Sync agent workspaces adds to new workspaces
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A" and "Team B"
    When I sync agent workspaces to include "Team A", "Team B", and "Team C"
    Then "My Helper" should be added to workspace "Team C"
    And "My Helper" should remain in "Team A" and "Team B"

  Scenario: Sync agent workspaces removes from old workspaces
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A", "Team B", and "Team C"
    When I sync agent workspaces to only "Team A" and "Team C"
    Then "My Helper" should be removed from workspace "Team B"
    And "My Helper" should remain in "Team A" and "Team C"
    And workspace "Team B" members should receive PubSub notification

  Scenario: Sync agent workspaces with no changes is idempotent
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A" and "Team B"
    When I sync agent workspaces to only "Team A" and "Team B"
    Then no workspace associations should be added or removed
    And no PubSub notifications should be sent

  # PubSub Notifications
  Scenario: Agent update broadcasts to affected workspaces only
    Given I have an agent "Shared Bot" in workspaces "Team A" and "Team B"
    And "Team A" and "Team B" members are connected
    When I update "Shared Bot" configuration
    Then "Team A" members should receive a workspace agent updated message
    And "Team B" members should receive a workspace agent updated message
    And members of other workspaces should not receive notifications

  Scenario: Agent removal broadcasts to affected workspace
    Given I have an agent "Helper" in workspace "Team A"
    And "Team A" members are connected
    When I remove "Helper" from workspace "Team A"
    Then "Team A" members should receive agent removed notification
    And their chat panels should refresh the agent list

  Scenario: Agent addition broadcasts to affected workspace
    Given I have an agent "Helper"
    And a workspace "Team B" exists
    And "Team B" members are connected
    When I add "Helper" to workspace "Team B"
    Then "Team B" members should receive agent added notification
    And "Helper" should appear in their agent selectors"
