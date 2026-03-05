@security
Feature: Agents REST API Security Baseline
  As a security engineer
  I want to verify the Agents REST API is free from common vulnerabilities
  So that agent metadata, prompt content, and authenticated API operations are protected against attack

  The Agents REST API exposes 9 endpoints across public and authenticated scopes:
  - Public: GET /api/health, GET /api/openapi
  - Authenticated: GET /api/agents, GET /api/agents/:id, POST /api/agents,
    PATCH /api/agents/:id, DELETE /api/agents/:id, POST /api/agents/:id/query,
    GET /api/agents/:id/skills

  The primary injection vector is POST /api/agents/:id/query because it accepts
  free-text question input that may carry attacker-controlled payloads. Additional
  user-controlled fields are accepted by POST/PATCH /api/agents, including
  name, description, and system_prompt, which may later be rendered or processed.

  Background:
    Given I set variable "apiBase" to "${baseUrl}/api"
    Given I set variable "healthEndpoint" to "${baseUrl}/api/health"
    Given I set variable "agentsEndpoint" to "${baseUrl}/api/agents"
    Given I set variable "openApiEndpoint" to "${baseUrl}/api/openapi"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # What: Spider base API routes and key public/authenticated entry points.
  # Why: Ensure ZAP discovers reachable paths before deeper scans.
  # Mapping: /api (route index), /api/health (public), /api/agents (auth gateway
  # to list/create and nested :id, :id/query, :id/skills operations).
  # ===========================================================================

  Scenario: Spider discovers API base attack surface
    Given a new ZAP session
    When I spider "${apiBase}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers health endpoint attack surface
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers agents endpoint attack surface
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING
  # What: Run non-intrusive passive analysis on traffic for key endpoints.
  # Why: Detect header/cookie/misconfiguration weaknesses without attack payloads.
  # Mapping: /api/agents covers authenticated CRUD/query surface; /api/health
  # verifies public endpoint hardening with minimal business logic.
  # ===========================================================================

  Scenario: Passive scan on agents endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    And I run a passive scan on "${agentsEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  Scenario: Passive scan on health endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — SQL Injection
  # What: Active probing for SQL injection payload handling.
  # Why: User-controlled fields must never alter query structure or persistence.
  # Mapping: POST/PATCH /api/agents fields (name, description, system_prompt),
  # POST /api/agents/:id/query question input, and :id path parameter usage.
  # ===========================================================================

  Scenario: No SQL Injection on agents endpoint
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on health endpoint
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — Cross-Site Scripting (XSS)
  # What: Active testing for reflected and persistent script injection vectors.
  # Why: Agent metadata may be stored and returned by GET endpoints, enabling
  # stored-XSS chains if output encoding is incorrect.
  # Mapping: POST/PATCH /api/agents user fields rendered in GET /api/agents and
  # GET /api/agents/:id responses; reflected behavior checked across endpoints.
  # ===========================================================================

  Scenario: No Cross-Site Scripting on agents endpoint
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on health endpoint
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — Path Traversal
  # What: Active tests for directory/path traversal payload acceptance.
  # Why: Route parameters must be validated and constrained to safe identifiers.
  # Mapping: /api/agents/:id, /api/agents/:id/query, /api/agents/:id/skills,
  # and DELETE/PATCH variants that consume :id path parameters.
  # ===========================================================================

  Scenario: No path traversal on agents endpoint
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — Remote Code Execution
  # What: Active checks for command/code execution primitives.
  # Why: Free-text question input must not be interpreted by shell/runtime layers.
  # Mapping: POST /api/agents/:id/query question payload and any downstream tool
  # execution paths that process prompt-like or command-like content.
  # ===========================================================================

  Scenario: No remote code execution on agents endpoint
    Given a new ZAP session
    When I spider "${agentsEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN
  # What: Perform broad active scanning after spidering all configured endpoints.
  # Why: Catch cross-endpoint issues and aggregate alert posture in one run.
  # Mapping: /api base, /api/health, /api/openapi, /api/agents (covering nested
  # authenticated operations including list/get/create/update/delete/query/skills).
  # ===========================================================================

  Scenario: Comprehensive active scan on Agents API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${apiBase}"
    And I spider "${healthEndpoint}"
    And I spider "${openApiEndpoint}"
    And I spider "${agentsEndpoint}"
    And I run an active scan on "${apiBase}"
    And I run an active scan on "${healthEndpoint}"
    And I run an active scan on "${openApiEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # BASELINE SCAN
  # What: Run fast baseline scans suitable for CI/CD quality gates.
  # Why: Provide quick regression signals on critical vulnerabilities.
  # Mapping: /api/agents (high-value auth surface) and /api/health (public probe).
  # ===========================================================================

  Scenario: Baseline scan on agents endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${agentsEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on health endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS
  # What: Validate presence of recommended defensive HTTP response headers.
  # Why: Headers reduce exploitability of XSS, clickjacking, and MIME confusion.
  # Mapping: Public health endpoint and authenticated agents collection endpoint.
  # ===========================================================================

  Scenario: Health endpoint returns proper security headers
    When I check "${healthEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Agents endpoint returns proper security headers
    When I check "${agentsEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test
  # environment because the Agents API runs over plain HTTP on port 5008.
  # In staging/production, SSL certificate checks should be added:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://agents-api.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 90 days
  # ===========================================================================

  # ===========================================================================
  # SECURITY REPORTING — Audit Trail
  # What: Produce HTML and JSON artifacts for audit/compliance evidence.
  # Why: Preserve scan findings and prove recurring security verification.
  # Mapping: Includes public endpoints and authenticated agents surface.
  # ===========================================================================

  Scenario: Generate security audit report for Agents REST API
    Given a new ZAP session
    When I spider "${apiBase}"
    And I spider "${healthEndpoint}"
    And I spider "${openApiEndpoint}"
    And I spider "${agentsEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    And I run a passive scan on "${agentsEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    And I run an active scan on "${agentsEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/agents-api-security-audit.html"
    And I save the security report as JSON to "reports/agents-api-security-audit.json"
