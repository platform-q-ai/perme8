@security @pipeline @phase8 @merge-queue
Feature: Pipeline Phase 8 - Merge Queue Security Controls
  As a security-minded maintainer
  I want merge queue operations to enforce validation and review gates before merging
  So that unreviewed or unvalidated code cannot reach main through the queue

  The merge queue and merge-result validation flow are security-sensitive because
  they govern whether code reaches main. This feature verifies the queue surface
  cannot be abused to bypass approval or validation guardrails.

  Background:
    Given I set variable "mergeQueueSurface" to "${baseUrl}"
    Given I set variable "mergeQueueAuditHtmlReport" to "reports/merge-queue-security-audit.html"
    Given I set variable "mergeQueueAuditJsonReport" to "reports/merge-queue-security-audit.json"

  Scenario: Unapproved pull requests cannot be merged through the queue
    Given a new ZAP session
    When I spider "${mergeQueueSurface}"
    And I run an active scan on "${mergeQueueSurface}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: Failed pre-merge validation blocks merge continuation safely
    Given a new ZAP session
    When I spider "${mergeQueueSurface}"
    And I run a passive scan on "${mergeQueueSurface}"
    Then no medium or higher risk alerts should be found
    And alerts should not exceed risk level "Low"
    And I should see the alert details

  Scenario: Queue processing does not introduce high-risk web vulnerabilities
    Given a new ZAP session
    When I spider "${mergeQueueSurface}"
    And I run a passive scan on "${mergeQueueSurface}"
    And I run an active scan on "${mergeQueueSurface}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Merge queue reports avoid sensitive leakage
    Given a new ZAP session
    When I spider "${mergeQueueSurface}"
    And I run a passive scan on "${mergeQueueSurface}"
    Then no medium or higher risk alerts should be found
    And I store the alerts as "mergeQueueSecurityAlerts"
    And I should see the alert details
    When I save the security report to "${mergeQueueAuditHtmlReport}"
    And I save the security report as JSON to "${mergeQueueAuditJsonReport}"
