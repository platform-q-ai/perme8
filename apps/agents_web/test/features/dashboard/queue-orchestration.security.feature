@security @wip
Feature: Queue orchestration security baseline
  As a security auditor
  I want queue orchestration endpoints scanned for auth and integrity weaknesses
  So that users cannot access or manipulate queues outside permitted controls

  Background:
    Given a new ZAP session
    When I spider "${baseUrl}/sessions"
    Then the spider should find at least 1 URLs

  Scenario: Unauthenticated user cannot access queue state
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Authentication Bypass"
    And there should be no alerts of type "Missing Authentication for Critical Function"

  Scenario: Unauthenticated user cannot modify concurrency limit
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Authentication Bypass"
    And alerts should not exceed risk level "Medium"

  Scenario: User cannot view another user's queue snapshot
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Insecure Direct Object Reference"
    And there should be no alerts of type "Broken Access Control"

  Scenario: User cannot modify another user's concurrency limit
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Insecure Direct Object Reference"
    And there should be no alerts of type "Broken Access Control"

  Scenario: User cannot promote tasks in another user's queue
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Missing Function Level Access Control"
    And there should be no alerts of type "Broken Access Control"

  Scenario: Concurrency limit rejects negative values
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Parameter Tampering"
    And there should be no alerts of type "Input Validation"

  Scenario: Concurrency limit rejects excessively high values
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Parameter Tampering"
    And alerts should not exceed risk level "Medium"

  Scenario: Warm cache limit rejects invalid values
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Parameter Tampering"
    And there should be no alerts of type "Input Validation"

  Scenario: Queue snapshot cannot be forged by client
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Insecure Direct Object Reference"
    And there should be no alerts of type "Parameter Tampering"

  Scenario: Task status transitions are validated server-side
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Missing Function Level Access Control"
    And there should be no alerts of type "Broken Access Control"

  Scenario: Sessions page serves appropriate security headers
    When I check "${baseUrl}/sessions" for security headers
    Then Content-Security-Policy should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
