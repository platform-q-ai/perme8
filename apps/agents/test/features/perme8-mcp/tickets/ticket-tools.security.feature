@security
Feature: Ticket Management MCP Tools Security Baseline
  As a security-conscious operator
  I want ticket management MCP tools to enforce secure access patterns
  So that unauthorized issue-management operations are prevented

  Background:
    Given I set variable "mcpEndpoint" to "${baseUrl}/"

  Scenario: Unauthenticated requests expose no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And no medium risk alerts should be found

  Scenario: Revoked API key context exposes no additional attack surface
    Given a new ZAP session
    When I spider "${mcpEndpoint}" as authenticated with token "${revoked-key-product-team}"
    And I run a passive scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And no medium risk alerts should be found

  Scenario: API key without ticket scopes is hardened against misuse
    Given a new ZAP session
    When I spider "${mcpEndpoint}" as authenticated with token "${valid-no-access-key}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: Ticket tools with valid scoped key resist injection and input abuse
    Given a new ZAP session
    When I spider "${mcpEndpoint}" as authenticated with token "${valid-doc-key-product-team}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"

  Scenario: MCP endpoint returns required security headers
    When I check "${mcpEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Content-Security-Policy"

  Scenario: Generate ticket tools security report
    Given a new ZAP session
    When I spider "${mcpEndpoint}" as authenticated with token "${valid-doc-key-product-team}"
    And I run a passive scan on "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And no medium risk alerts should be found
    When I save the security report to "reports/perme8-mcp-ticket-tools-security.html"
