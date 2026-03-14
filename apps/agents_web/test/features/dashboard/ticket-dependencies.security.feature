@security @sessions @ticket-dependencies @wip
Feature: Security posture for ticket dependency management
  As a platform owner
  I want ticket dependency management to enforce authentication, access control, and input safety
  So that dependency data is protected against common vulnerabilities and unauthorized access

  Scenario: Unauthenticated user cannot manage ticket dependencies
    Given I am not authenticated
    When I attempt to add a dependency between tickets
    Then the request should be rejected as unauthorized

  Scenario: Non-workspace-member cannot view ticket dependencies
    Given I am authenticated but not a member of the workspace
    When I attempt to view ticket dependencies in the sessions dashboard
    Then I should not see any dependency data
    And the request should be rejected as forbidden

  Scenario: Security headers present on dependency-related responses
    Given I am authenticated
    When I load the sessions dashboard that renders ticket dependencies
    Then the response includes standard security headers
    And Content-Security-Policy header is present
    And X-Frame-Options header is present
    And X-Content-Type-Options header is present
    And Strict-Transport-Security header is present

  Scenario: Dependency operations are protected against CSRF
    Given I am authenticated
    When I submit a dependency add or remove action
    Then the request includes CSRF protection via LiveView socket
    And forged requests without valid CSRF tokens are rejected

  Scenario: No XSS vulnerability in dependency display
    Given a ticket has a dependency on a ticket with a title containing script tags
    When I view the dependency in the ticket detail panel
    Then the malicious content is safely escaped in the rendered HTML
    And no script execution occurs

  Scenario: No injection vulnerability in dependency search typeahead
    Given I am authenticated and viewing a ticket's detail panel
    When I type SQL injection or script injection payloads into the dependency search typeahead
    Then the input is safely sanitized
    And no injection attack succeeds
    And the search returns safe results or no results

  Scenario: Dependency validation prevents malformed input
    Given I am authenticated
    When I attempt to create a dependency with invalid ticket references
    Then the system rejects the request with validation errors
    And no partial or corrupted data is persisted

  Scenario: Dependency data isolation between workspaces
    Given workspace A has tickets with dependencies
    And I am a member of workspace B but not workspace A
    When I attempt to access workspace A's dependency data
    Then I cannot see or modify workspace A's dependencies
