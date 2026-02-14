@security
Feature: Workspace API Security Baseline
  As a security engineer
  I want to verify the Workspace API endpoints are free from common vulnerabilities
  So that workspace data, API keys, and cross-workspace isolation are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL)
    Given I set variable "workspaceListEndpoint" to "${baseUrl}/api/workspaces"
    Given I set variable "workspaceShowEndpoint" to "${baseUrl}/api/workspaces/product-team"
    Given I set variable "crossWorkspaceEndpoint" to "${baseUrl}/api/workspaces/engineering"

  # ---------------------------------------------------------------------------
  # Attack Surface Discovery
  # Maps to: all scenarios -- understanding the full API surface before scanning
  # ---------------------------------------------------------------------------

  Scenario: Spider discovers workspace list API attack surface
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers workspace show API attack surface
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    Then the spider should find at least 1 URLs

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Workspace List Endpoint (GET)
  # Maps to: List all workspaces (200), no workspace access returns empty list (200),
  #          revoked/invalid key returns 401
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on workspace list endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I run a passive scan on "${workspaceListEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Workspace Show Endpoint (GET)
  # Maps to: User accesses workspace details (200), cross-workspace access denied (403),
  #          revoked/invalid key returns 401, workspace not found (404),
  #          guest role can access workspace (200), response includes documents and projects
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on workspace show endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    And I run a passive scan on "${workspaceShowEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- SQL Injection
  # Maps to: All endpoints that accept user input (slug parameters in URLs)
  # Covers: Workspace list filtering, workspace slug parameter in show endpoint,
  #         workspace not found (404), revoked/invalid key (401)
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on workspace list endpoint
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on workspace show endpoint
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Site Scripting (XSS)
  # Maps to: Workspace details retrieval where workspace name, document titles,
  #          and project names are returned -- potential for stored XSS if
  #          workspace/document/project names contain malicious content
  # Covers: Get workspace with documents and projects, single workspace access
  # ---------------------------------------------------------------------------

  Scenario: No Cross-Site Scripting on workspace list endpoint
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on workspace show endpoint
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Path Traversal
  # Maps to: Workspace not found (404), cross-workspace access denied (403)
  # Covers: Slug parameter (:slug) in the URL path -- attackers may attempt
  #         ../../etc/passwd style traversal via workspace slugs
  # ---------------------------------------------------------------------------

  Scenario: No path traversal on workspace list endpoint
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on workspace show endpoint
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Command Injection
  # Maps to: Workspace slug parameter could be crafted as a shell command
  #          if improperly handled during lookup
  # Covers: Slug parameter in URL path for show endpoint
  # ---------------------------------------------------------------------------

  Scenario: No remote code execution on workspace list endpoint
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on workspace show endpoint
    Given a new ZAP session
    When I spider "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Workspace Isolation
  # Maps to: "Cross-workspace access denied (403)",
  #          "Single workspace access (200)" -- only own workspaces visible
  # Tests: Scanning the cross-workspace endpoint for authorization bypass vulns
  # ---------------------------------------------------------------------------

  Scenario: No authorization bypass on cross-workspace access
    Given a new ZAP session
    When I spider "${crossWorkspaceEndpoint}"
    And I run an active scan on "${crossWorkspaceEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ---------------------------------------------------------------------------
  # Comprehensive Active Scan -- Full Workspace API
  # Maps to: All scenarios combined -- deep active scan across all endpoints
  # ---------------------------------------------------------------------------

  Scenario: Comprehensive active scan on workspace API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I spider "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Baseline Scan -- Quick Combined Spider + Passive
  # Maps to: Overall workspace API health check (list and show scenarios)
  # ---------------------------------------------------------------------------

  Scenario: Baseline scan on workspace list endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceListEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on workspace show endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceShowEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ---------------------------------------------------------------------------
  # Security Headers -- API Response Hardening
  # Maps to: All API responses -- every scenario that returns JSON should include
  #          proper security headers to prevent MIME-sniffing, clickjacking, etc.
  # NOTE: checkSecurityHeaders sends a GET request, so we test against endpoints
  #       that have GET routes. The SecurityHeadersPlug is applied at the pipeline
  #       level, so it covers all HTTP methods on all routed endpoints uniformly.
  # ---------------------------------------------------------------------------

  Scenario: Workspace list endpoint returns proper security headers
    When I check "${workspaceListEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Workspace show endpoint returns proper security headers
    When I check "${workspaceShowEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # NOTE: SSL/TLS certificate validation is skipped in the local test environment
  # because the test server runs over plain HTTP. In staging/production,
  # SSL certificate checks should be added against the HTTPS endpoint.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Security Reporting -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan suite
  # ---------------------------------------------------------------------------

  Scenario: Generate security audit report for workspace API
    Given a new ZAP session
    When I spider "${workspaceListEndpoint}"
    And I spider "${workspaceShowEndpoint}"
    And I run a passive scan on "${workspaceListEndpoint}"
    And I run a passive scan on "${workspaceShowEndpoint}"
    And I run an active scan on "${workspaceListEndpoint}"
    And I run an active scan on "${workspaceShowEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/workspace-api-security-audit.html"
    And I save the security report as JSON to "reports/workspace-api-security-audit.json"
