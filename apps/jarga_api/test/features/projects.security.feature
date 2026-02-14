@security
Feature: Project API Security Baseline
  As a security engineer
  I want to verify the Project API endpoints are free from common vulnerabilities
  So that project data, API keys, and workspace isolation are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL)
    Given I set variable "projectCreateEndpoint" to "${baseUrl}/api/workspaces/product-team/projects"
    Given I set variable "projectShowEndpoint" to "${baseUrl}/api/workspaces/product-team/projects/q1-launch"
    Given I set variable "crossWorkspaceEndpoint" to "${baseUrl}/api/workspaces/engineering/projects"

  # ---------------------------------------------------------------------------
  # Attack Surface Discovery
  # Maps to: all scenarios -- understanding the full API surface before scanning
  # ---------------------------------------------------------------------------

  Scenario: Spider discovers project creation API attack surface
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers project retrieval API attack surface
    Given a new ZAP session
    When I spider "${projectShowEndpoint}"
    Then the spider should find at least 1 URLs

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Project Create Endpoint (POST)
  # Maps to: Create project scenarios (valid creation, invalid data, guest role
  #          denied, owner/member can create, revoked/invalid API key)
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on project creation endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I run a passive scan on "${projectCreateEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Project Retrieve Endpoint (GET)
  # Maps to: Retrieve project scenarios (by slug, with documents, cross-workspace
  #          access denied, not found, revoked/invalid key, guest role access)
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on project retrieval endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${projectShowEndpoint}"
    And I run a passive scan on "${projectShowEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- SQL Injection
  # Maps to: All endpoints that accept user input (slug parameters in URLs,
  #          JSON body with name/description fields)
  # Covers: API key without workspace access, cross-workspace isolation,
  #         create with invalid data, non-existent project
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on project creation endpoint
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I run an active scan on "${projectCreateEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on project retrieval endpoint
    Given a new ZAP session
    When I spider "${projectShowEndpoint}"
    And I run an active scan on "${projectShowEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Site Scripting (XSS)
  # Maps to: Create project scenarios where name/description are stored and
  #          later retrieved via GET -- potential for stored XSS if content
  #          is rendered. Project response includes associated documents,
  #          adding further surface for reflected content.
  # Covers: Name and description fields in POST request body, document titles
  #         in GET response
  # ---------------------------------------------------------------------------

  Scenario: No Cross-Site Scripting on project creation endpoint
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I run an active scan on "${projectCreateEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on project retrieval endpoint
    Given a new ZAP session
    When I spider "${projectShowEndpoint}"
    And I run an active scan on "${projectShowEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Additional Injection Vectors
  # Maps to: Invalid data scenarios, non-existent project paths, revoked keys
  # Covers: Path traversal via slug params (:workspace_slug, :slug),
  #         command injection via JSON fields (name, description)
  # ---------------------------------------------------------------------------

  Scenario: No path traversal on project retrieval endpoint
    Given a new ZAP session
    When I spider "${projectShowEndpoint}"
    And I run an active scan on "${projectShowEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No remote code execution on project creation endpoint
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I run an active scan on "${projectCreateEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Workspace Isolation
  # Maps to: "API key without workspace access cannot create project",
  #          "API key cannot access project in workspace it doesn't have access to"
  # Tests: Scanning the cross-workspace endpoint for authorization bypass vulns
  # ---------------------------------------------------------------------------

  Scenario: No authorization bypass on cross-workspace project access
    Given a new ZAP session
    When I spider "${crossWorkspaceEndpoint}"
    And I run an active scan on "${crossWorkspaceEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ---------------------------------------------------------------------------
  # Comprehensive Active Scan -- Full Project API
  # Maps to: All scenarios combined -- deep active scan across all endpoints
  # ---------------------------------------------------------------------------

  Scenario: Comprehensive active scan on project API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I spider "${projectShowEndpoint}"
    And I run an active scan on "${projectCreateEndpoint}"
    And I run an active scan on "${projectShowEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Baseline Scan -- Quick Combined Spider + Passive
  # Maps to: Overall project API health check (create and retrieval scenarios)
  # ---------------------------------------------------------------------------

  Scenario: Baseline scan on project create endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${projectCreateEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on project retrieval endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${projectShowEndpoint}"
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

  Scenario: Project retrieval endpoint returns proper security headers
    When I check "${projectShowEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Workspace projects endpoint returns proper security headers
    When I check "${baseUrl}/api/workspaces/product-team" for security headers
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

  Scenario: Generate security audit report for project API
    Given a new ZAP session
    When I spider "${projectCreateEndpoint}"
    And I spider "${projectShowEndpoint}"
    And I run a passive scan on "${projectCreateEndpoint}"
    And I run a passive scan on "${projectShowEndpoint}"
    And I run an active scan on "${projectCreateEndpoint}"
    And I run an active scan on "${projectShowEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/project-api-security-audit.html"
    And I save the security report as JSON to "reports/project-api-security-audit.json"
