@security
Feature: Ticket Management MCP Tools Security Delta
  As a security engineer
  I want to verify ticket MCP tools on the shared MCP endpoint are free from common vulnerabilities
  So that ticket data, permission-scoped operations, API keys, and the JSON-RPC interface are protected against attack

  The ticket tools (ticket.read, ticket.list, ticket.create, ticket.update,
  ticket.close, ticket.comment, ticket.add_sub_issue, ticket.remove_sub_issue)
  share the same POST / MCP endpoint as existing tools.

  This feature focuses on the incremental ticket-specific attack surface:
  - integer parameters (issue numbers)
  - string and markdown parameters (titles, bodies, comments)
  - array parameters (labels, assignees)
  - permission-guarded ticket scopes (mcp:ticket.*) and token handling

  Background:
    Given I set variable "mcpEndpoint" to "${baseUrl}/"
    Given I set variable "ticketAuditHtmlReport" to "reports/ticket-tools-security-audit.html"
    Given I set variable "ticketAuditJsonReport" to "reports/ticket-tools-security-audit.json"

  Scenario: Active scan finds no injection vulnerabilities in ticket tool parameter shapes
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"

  Scenario: Passive scan finds no sensitive leakage in ticket tool auth and validation responses
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    Then no medium or higher risk alerts should be found
    And alerts should not exceed risk level "Low"
    And I should see the alert details

  Scenario: Generate ticket tools security audit report
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I store the alerts as "ticketToolsSecurityAlerts"
    And I should see the alert details
    When I save the security report to "${ticketAuditHtmlReport}"
    And I save the security report as JSON to "${ticketAuditJsonReport}"
