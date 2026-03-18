@security @analytics
Feature: Security posture for Analytics Dashboard
  As a platform owner
  I want the analytics dashboard to enforce proper authentication and data isolation
  So that workspace analytics data is not exposed to unauthorized users

  # The Analytics dashboard displays ticket lifecycle analytics scoped to a
  # workspace. Authentication is session-based via the Identity app.
  # All authenticated workspace members can view analytics for their workspace.
  # Data must be isolated by workspace -- users must not see other workspaces' data.
  #
  # NOTE: This is an EARLY-PIPELINE feature file. Steps use business-language
  # descriptions of security intent. Concrete implementation details will be
  # refined after the architect produces an implementation plan.

  Scenario: Unauthenticated user cannot access the analytics dashboard
    Given I am not authenticated
    When I attempt to access the analytics dashboard
    Then the request should be rejected as unauthorized
    And I should be redirected to the login page

  Scenario: User cannot view analytics for a workspace they do not belong to
    Given I am authenticated as a user
    And I am not a member of the target workspace
    When I attempt to access analytics for the target workspace
    Then the analytics data should not be returned
    And I should be denied access

  Scenario: Analytics data is scoped to the current workspace only
    Given I am authenticated as a member of workspace A
    When I view the analytics dashboard
    Then I should only see ticket lifecycle data for workspace A
    And no data from other workspaces should be visible or queryable

  Scenario: Analytics page includes standard security headers
    Given I am authenticated
    When I load the analytics dashboard page
    Then the response should include Content-Security-Policy headers
    And the response should include X-Frame-Options set to deny framing
    And the response should include X-Content-Type-Options nosniff

  Scenario: Analytics queries do not leak internal details through error messages
    Given I am authenticated
    When I request analytics with invalid or malformed parameters
    Then the response should return a safe user-facing error message
    And no internal system details, stack traces, or SQL fragments should be exposed
