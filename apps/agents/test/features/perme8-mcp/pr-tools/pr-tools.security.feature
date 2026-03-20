@security
Feature: Pull Request MCP Tools Security Delta
  As a security engineer
  I want to verify internal pull request MCP tools on the shared MCP endpoint are protected
  So that pull request metadata, review data, diffs, merge actions, and branch operations are not exposed to common vulnerabilities

  The PR tools (mcp:pr.* scope) share a single JSON-RPC endpoint at POST /mcp,
  with a separate health endpoint at GET /mcp/health.

  This feature focuses on the incremental PR-specific attack surface:
  - JSON-RPC input validation for branch names, titles, bodies, comments, and review payloads
  - auth and permission scope boundaries for mcp:pr.* operations
  - diff retrieval and merge responses that must avoid leaking sensitive internals
  - merge actions that can affect main and require strong guardrails

  Background:
    Given I set variable "mcpEndpoint" to "${baseUrl}"
    Given I set variable "healthEndpoint" to "http://localhost:4000/mcp/health"
    Given I set variable "prAuditHtmlReport" to "reports/pr-tools-security-audit.html"
    Given I set variable "prAuditJsonReport" to "reports/pr-tools-security-audit.json"

  Scenario: Active scan finds no injection vulnerabilities in pull request tool parameter shapes
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"

  Scenario: Passive scan finds no sensitive leakage in auth, validation, diff, and merge responses
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I spider "${healthEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    Then no medium or higher risk alerts should be found
    And alerts should not exceed risk level "Low"
    And I should see the alert details

  Scenario: Generate pull request tools security audit report
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I spider "${healthEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I store the alerts as "prToolsSecurityAlerts"
    And I should see the alert details
    When I save the security report to "${prAuditHtmlReport}"
    And I save the security report as JSON to "${prAuditJsonReport}"
