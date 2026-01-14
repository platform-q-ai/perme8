Feature: Agent CRUD Operations
  As a user
  I want to create, update, and delete AI agents
  So that I can customize my AI assistant experiences

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

  # Agent Updates

  Scenario: Update agent configuration
    Given I have an agent named "My Assistant"
    When I navigate to the agents page
    And I click edit on "My Assistant"
    And I change the system prompt to "You are a helpful coding assistant"
    And I change the model to "gpt-4-turbo"
    And I submit the agent edit form
    Then the agent "My Assistant" should have the updated system prompt
    And the agent "My Assistant" should have model "gpt-4-turbo"

  Scenario: Update agent visibility from PRIVATE to SHARED
    Given I have an agent named "Personal Assistant" with visibility "PRIVATE"
    When I navigate to the agents page
    And I click edit on "Personal Assistant"
    And I change the visibility to "SHARED"
    And I submit the agent edit form
    Then the agent "Personal Assistant" should have visibility "SHARED"
    And other workspace members should be able to see the agent

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
    And I confirm the agent deletion
    Then "Old Assistant" should not appear in my agents list

  Scenario: Cannot delete another user's agent
    Given another user has created an agent named "Their Agent"
    When I attempt to delete "Their Agent"
    Then I should see an error "not_found"
    And the agent should still exist

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

  Scenario: Cannot clone private agent that's not mine
    Given another user has a private agent named "Private Helper"
    When I attempt to clone "Private Helper"
    Then the clone operation should fail with "forbidden"
    And the agent should not be cloned

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

  Scenario: Handle agent not found gracefully
    Given I have an agent with ID "abc-123"
    When the agent is deleted by another process
    And I attempt to load the agent
    Then I should receive an error "not_found"

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
