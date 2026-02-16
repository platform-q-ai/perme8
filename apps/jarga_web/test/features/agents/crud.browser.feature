@browser @agents
Feature: Agent CRUD Operations
  As a user
  I want to create, update, and delete AI agents
  So that I can customize my AI assistant experiences

  # Seed data: alice@example.com (owner) has two agents seeded:
  #   - "Code Helper" (SHARED, model: gpt-4o)
  #   - "Doc Writer" (SHARED, model: gpt-4o)
  # The agent management pages live under /app/agents (LiveView).
  # Agent form uses Phoenix form with `as: :agent` so field IDs are agent_<field>.
  # "New Agent" renders as a link (<a>) navigating to /app/agents/new.
  # Submit button text is "Save Agent".
  # Delete uses data-confirm (native browser dialog) — cannot be tested via standard steps.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # Agent Listing

  Scenario: View my agents list shows seeded agents
    When I navigate to "${baseUrl}/app/agents"
    And I wait for network idle
    Then I should see "My Agents"
    And I should see "Code Helper"
    And I should see "Doc Writer"

  Scenario: Agent list shows table with name and model columns
    When I navigate to "${baseUrl}/app/agents"
    And I wait for network idle
    Then "table.table-zebra" should exist
    And I should see "Name"
    And I should see "Model"
    And I should see "Actions"

  # Agent Creation

  Scenario: Navigate to new agent form
    When I navigate to "${baseUrl}/app/agents"
    And I wait for network idle
    And I click the "New Agent" link and wait for navigation
    Then the URL should contain "/app/agents/new"
    And I should see "New Agent"
    And "#agent_name" should exist

  Scenario: Create a new agent with name only
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I fill "#agent_name" with "My Test Agent"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "Agent created successfully"
    And I should see "My Test Agent"

  Scenario: Create an agent with full configuration
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I fill "#agent_name" with "Code Reviewer"
    And I fill "#agent_description" with "Reviews code for best practices"
    And I fill "#agent_system_prompt" with "You are an expert code reviewer."
    And I fill "#agent_model" with "gpt-4-turbo"
    And I clear "#agent_temperature"
    And I fill "#agent_temperature" with "0.3"
    And I select "Shared" from "#agent_visibility"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "Agent created successfully"
    And I should see "Code Reviewer"

  Scenario: Create agent without required name shows validation error
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I clear "#agent_name"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "can't be blank"

  Scenario: Create agent with invalid temperature shows validation error
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I fill "#agent_name" with "Bad Temp Agent"
    And I clear "#agent_temperature"
    And I fill "#agent_temperature" with "2.5"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "must be less than or equal to 2"

  Scenario: Create agent with valid temperature succeeds
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I fill "#agent_name" with "Valid Temp Agent"
    And I clear "#agent_temperature"
    And I fill "#agent_temperature" with "1.5"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "Agent created successfully"
    And I should see "Valid Temp Agent"

  Scenario: New agent defaults to Private visibility
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    Then "#agent_visibility" should have value "PRIVATE"

  Scenario: New agent form has cancel link
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    Then I should see "Cancel"

  Scenario: Cancel returns to agents list
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    And I click the "Cancel" link and wait for navigation
    Then the URL should contain "/app/agents"
    And I should see "My Agents"

  # Agent Updates

  Scenario: Edit seeded agent configuration
    When I navigate to "${baseUrl}/app/agents"
    And I wait for network idle
    # Click the edit (pencil) icon for the first agent in the table
    And I click "a.btn-ghost[href*='/edit']"
    And I wait for network idle
    Then I should see "Edit Agent"
    And "#agent_name" should exist

  Scenario: Update agent name and save
    When I navigate to "${baseUrl}/app/agents"
    And I wait for network idle
    And I click "a.btn-ghost[href*='/edit']"
    And I wait for network idle
    And I clear "#agent_name"
    And I fill "#agent_name" with "Updated Agent Name"
    And I click the "Save Agent" button
    And I wait for network idle
    Then I should see "Agent updated successfully"

  # Agent Not Found

  Scenario: Handle agent not found gracefully
    When I navigate to "${baseUrl}/app/agents/00000000-0000-0000-0000-000000000000/edit"
    And I wait for network idle
    Then I should see "Agent not found"
    And the URL should contain "/app/agents"

  # Agent Form Fields

  Scenario: Agent form has all expected fields
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    Then "#agent_name" should exist
    And "#agent_description" should exist
    And "#agent_system_prompt" should exist
    And "#agent_model" should exist
    And "#agent_temperature" should exist
    And "#agent_visibility" should exist

  Scenario: Temperature field has correct attributes
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    Then "#agent_temperature[type='number']" should exist
    And "#agent_temperature[min='0']" should exist
    And "#agent_temperature[max='2']" should exist
    And "#agent_temperature[step='0.1']" should exist

  Scenario: Visibility select has Private and Shared options
    When I navigate to "${baseUrl}/app/agents/new"
    And I wait for network idle
    Then "#agent_visibility option[value='PRIVATE']" should exist
    And "#agent_visibility option[value='SHARED']" should exist
