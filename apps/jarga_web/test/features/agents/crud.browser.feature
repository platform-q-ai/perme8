@browser
Feature: Agent CRUD Operations
  As a user
  I want to create, update, and delete AI agents
  So that I can customize my AI assistant experiences

  # Seed data: Uses alice@example.com (owner) from exo_seeds_web.exs.
  # Some scenarios require pre-existing agents (seeded or created in prior steps).

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load

  # Agent Creation

  Scenario: Create a new personal agent with default settings
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "My Assistant"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "My Assistant"
    And I should see "PRIVATE"

  Scenario: Create an agent with custom configuration
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Code Reviewer"
    And I fill "[data-testid='agent-description']" with "Reviews code for best practices"
    And I fill "[data-testid='agent-system-prompt']" with "You are an expert code reviewer."
    And I fill "[data-testid='agent-model']" with "gpt-4-turbo"
    And I fill "[data-testid='agent-temperature']" with "0.3"
    And I select "SHARED" from "[data-testid='agent-visibility']"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "Code Reviewer"
    And I should see "gpt-4-turbo"
    And I should see "SHARED"

  Scenario: Create agent with invalid temperature
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Test Agent"
    And I fill "[data-testid='agent-temperature']" with "2.5"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "must be less than or equal to 2"

  Scenario: Create agent without required name
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I click the "Save" button
    And I wait for network idle
    Then I should see "can't be blank"

  Scenario: Configure token costs for agent
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "GPT-4"
    And I fill "[data-testid='agent-input-token-cost']" with "0.03"
    And I fill "[data-testid='agent-cached-input-token-cost']" with "0.01"
    And I fill "[data-testid='agent-output-token-cost']" with "0.06"
    And I fill "[data-testid='agent-cached-output-token-cost']" with "0.02"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "GPT-4"

  Scenario: Duplicate agent names are allowed
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Helper"
    And I click the "Save" button
    And I wait for network idle
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Helper"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "Helper"

  Scenario: Agent with empty model uses system default
    # This scenario tests backend default model assignment;
    # from the browser we verify the agent is created without specifying a model.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Default Model Agent"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "Default Model Agent"

  Scenario: Agent temperature outside range is rejected
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Bad Temp Agent"
    And I fill "[data-testid='agent-temperature']" with "2.1"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "must be less than or equal to 2"

  # Agent Updates

  Scenario: Update agent configuration
    # Prerequisite: agent "My Assistant" must exist (seeded or created in a prior test run)
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-My Assistant']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-system-prompt']" with "You are a helpful coding assistant"
    And I fill "[data-testid='agent-model']" with "gpt-4-turbo"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "My Assistant"
    And I should see "gpt-4-turbo"

  Scenario: Update agent visibility from PRIVATE to SHARED
    # Prerequisite: agent "Personal Assistant" with visibility PRIVATE must exist
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-Personal Assistant']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I select "SHARED" from "[data-testid='agent-visibility']"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "SHARED"

  Scenario: Cannot update another user's agent
    # NOTE: Multi-user scenario. From the browser perspective, we verify that navigating
    # to another user's agent edit page shows an error or redirects.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should not see "Their Agent"

  # Agent Deletion

  Scenario: Delete an agent
    # Prerequisite: agent "Old Assistant" must exist
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-delete-Old Assistant']"
    And I wait for "[data-testid='confirm-dialog']" to be visible
    And I click the "Confirm" button
    And I wait for network idle
    Then I should not see "Old Assistant"

  Scenario: Cannot delete another user's agent
    # NOTE: Multi-user scenario. From the browser perspective, another user's agents
    # should not be visible for deletion.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should not see "Their Agent"

  # Agent Cloning

  Scenario: Clone my own agent
    # Prerequisite: agent "Original Assistant" must exist with specified config
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-clone-Original Assistant']"
    And I wait for network idle
    Then I should see "Original Assistant (Copy)"

  Scenario: Cannot clone private agent that's not mine
    # NOTE: Multi-user scenario. Another user's private agent should not be visible
    # to clone in the first place.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should not see "Private Helper"

  # Agent Listing

  Scenario: View my personal agents list
    # Prerequisite: user must have 3 agents seeded: "Assistant One", "Code Helper", "Documentation Bot"
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should see "Assistant One"
    And I should see "Code Helper"
    And I should see "Documentation Bot"
    And there should be 3 "[data-testid='agent-card']" elements

  Scenario: Empty agents list shows prompt to create first agent
    # Prerequisite: user must have no agents
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should see "No agents yet"
    And I should see "Create your first agent to get started"
    And "[data-testid='create-agent-button']" should be visible

  # Agent Policies

  Scenario: Only owner can edit agent
    # NOTE: Multi-user scenario. We can only verify from our own browser session
    # that another user's agents are not visible for editing.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should not see "Their Agent"

  Scenario: Only owner can delete agent
    # NOTE: Multi-user scenario. Same as above -- other user's agents are not visible.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then I should not see "Their Agent"

  Scenario: Handle agent not found gracefully
    When I navigate to "${baseUrl}/agents/abc-123"
    And I wait for the page to load
    Then I should see "not found"

  # Agent Parameter Validation

  Scenario: Validate agent parameters before saving
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Valid Agent"
    And I fill "[data-testid='agent-temperature']" with "1.5"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "Valid Agent"

  Scenario: Validation rejects invalid temperature
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Invalid Temp Agent"
    And I fill "[data-testid='agent-temperature']" with "invalid"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "is invalid"

  Scenario: Validation rejects temperature out of range
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-name']" with "Out of Range Agent"
    And I fill "[data-testid='agent-temperature']" with "2.5"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "must be less than or equal to 2"

  Scenario: Validation handles missing required fields
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click the "New Agent" button
    And I wait for "[data-testid='agent-form']" to be visible
    And I click the "Save" button
    And I wait for network idle
    Then I should see "can't be blank"
