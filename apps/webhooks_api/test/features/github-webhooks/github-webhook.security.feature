@security
Feature: GitHub Webhook Receiver Security
  As a security engineer
  I want to verify the GitHub webhook receiver endpoint is hardened against common web attacks
  So that webhook event processing remains safe without leaking secrets or internal details

  Background:
    Given I set variable "githubWebhookReceiverEndpoint" to "${baseUrl}/github-webhook-receiver-endpoint"

  Scenario: Spider maps the GitHub webhook receiver attack surface
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Passive scan finds no high-risk issues on the webhook receiver
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run a passive scan on "${githubWebhookReceiverEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  Scenario: Active scan finds no SQL Injection vulnerabilities on the webhook receiver
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run an active scan on "${githubWebhookReceiverEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: Active scan finds no reflected or persistent XSS on the webhook receiver
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run an active scan on "${githubWebhookReceiverEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: Active scan finds no path traversal vulnerabilities on the webhook receiver
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run an active scan on "${githubWebhookReceiverEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: Active scan finds no command injection vulnerabilities on the webhook receiver
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run an active scan on "${githubWebhookReceiverEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: GitHub webhook receiver responses include required security headers
    Given a new ZAP session
    When I check "${githubWebhookReceiverEndpoint}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"

  Scenario: Comprehensive security audit report for GitHub webhook receiver is generated
    Given a new ZAP session
    When I spider "${githubWebhookReceiverEndpoint}"
    And I run a passive scan on "${githubWebhookReceiverEndpoint}"
    And I run an active scan on "${githubWebhookReceiverEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And alerts should not exceed risk level "Medium"
    And I store the alerts as "githubWebhookSecurityAlerts"
    And I should see the alert details
    When I save the security report to "reports/github-webhook-security-audit.html"
    And I save the security report as JSON to "reports/github-webhook-security-audit.json"
