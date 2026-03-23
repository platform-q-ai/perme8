@browser @dashboard @pipeline-configuration
Feature: Pipeline Phase 11 - Pipeline Configuration UI
  As a platform operator
  I want to edit the pipeline configuration through stage cards in the dashboard
  So that I can manage the pipeline without editing YAML directly

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Successful login allows access to the pipeline configuration editor
    Given I open browser session "operator-login"
    And I navigate to "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_loaded"
    And I wait for network idle
    Then I should see "Pipeline configuration"

  Scenario: Invalid credentials are rejected
    Given I open browser session "invalid-login"
    And I navigate to "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "wrong@example.com"
    And I fill "#login_form_password_password" with "wrongpassword"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    Then the URL should contain "/log-in"
    And I should see "Invalid email or password"

  Scenario: Unauthenticated users are redirected to sign in
    Given I open browser session "guest"
    When I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_loaded"
    And I wait for network idle
    Then the URL should contain "/log-in"

  Scenario: Pipeline stages render as editable cards in configured order
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_loaded"
    And I wait for network idle
    Then "[data-testid='pipeline-stage-cards']" should be visible
    And "[data-testid='pipeline-stage-cards']" should contain text "Ready"
    And "[data-testid='pipeline-stage-cards']" should contain text "In Progress"
    And "[data-testid='pipeline-stage-cards']" should contain text "In Review"
    And "[data-testid='pipeline-stage-cards']" should contain text "Warm Pool"
    And "[data-testid='pipeline-stage-card-warm-pool']" should be visible

  Scenario: I edit step properties within a stage
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_step_editing"
    And I wait for network idle
    When I fill "[data-testid='step-command-input']" with "mix test"
    And I fill "[data-testid='step-timeout-input']" with "600"
    And I fill "[data-testid='step-conditions-input']" with "branch == main"
    And I fill "[data-testid='step-env-input']" with "MIX_ENV=test"
    Then "[data-testid='staged-pipeline-preview']" should contain text "mix test"
    And "[data-testid='staged-pipeline-preview']" should contain text "600"
    And "[data-testid='staged-pipeline-preview']" should contain text "branch == main"
    And "[data-testid='staged-pipeline-preview']" should contain text "MIX_ENV=test"

  Scenario: I edit warm pool settings
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_warm_pool_editing"
    And I wait for network idle
    When I fill "[data-testid='warm-pool-target-count-input']" with "5"
    And I fill "[data-testid='warm-pool-image-input']" with "ghcr.io/platform-q-ai/agent:stable"
    And I fill "[data-testid='warm-pool-step-command-input']" with "mix deps.get"
    Then "[data-testid='staged-pipeline-preview']" should contain text "target_count: 5"
    And "[data-testid='staged-pipeline-preview']" should contain text "ghcr.io/platform-q-ai/agent:stable"
    And "[data-testid='staged-pipeline-preview']" should contain text "mix deps.get"

  Scenario: I add, remove, and reorder stages and steps
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_structure_editing"
    And I wait for network idle
    When I click the "Add stage" button
    And I fill "[data-testid='new-stage-name-input']" with "Security Scan"
    And I click "[data-testid='add-step-security-scan']"
    And I fill "[name='new_step_command:2']" with "mix credo --strict"
    And I click "[data-testid='move-stage-security-scan-up']"
    And I click "[data-testid='move-step-security-scan-1-down']"
    And I click "[data-testid='remove-step-legacy-cleanup-1']"
    And I click "[data-testid='remove-stage-legacy-cleanup']"
    Then "[data-testid='staged-pipeline-preview']" should contain text "Security Scan"
    And "[data-testid='staged-pipeline-preview']" should contain text "mix credo --strict"
    And I should not see "Legacy Cleanup"

  Scenario: Invalid configuration changes are rejected before save
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_invalid_changes"
    And I wait for network idle
    When I click the "Save configuration" button
    And I wait for network idle
    Then I should see "Please resolve validation errors before saving"
    And I should see "Changes were not saved"
    And I should not see "Configuration saved"

  Scenario: Valid configuration changes persist back to YAML
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_configuration_editor_valid_changes"
    And I wait for network idle
    When I click the "Save configuration" button
    And I wait for network idle
    Then I should see "Configuration saved"
    And I should see "perme8-pipeline.yml"
    And I should see "No staged changes"
