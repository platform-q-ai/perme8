@security
Feature: Knowledge MCP Endpoint Security Baseline
  As a security engineer
  I want to verify the Knowledge MCP endpoint is free from common vulnerabilities
  So that knowledge data, API keys, workspace isolation, and the JSON-RPC interface are protected against attack

  The Knowledge MCP server exposes two routes:
  - POST / — JSON-RPC 2.0 endpoint for all 6 MCP tools (authenticated via Bearer token)
  - GET /health — unauthenticated health check

  All MCP tool operations (knowledge.search, knowledge.get, knowledge.traverse,
  knowledge.create, knowledge.update, knowledge.relate) flow through a single
  POST / endpoint, making it the primary attack surface. Input validation on
  tool parameters (title, body, category, tags, IDs, relationship types) must
  prevent injection attacks.

  Background:
    # baseUrl is auto-injected from exo-bdd config (security adapter uses http.baseURL)
    # The MCP server is a standalone Bandit on port 4007 with only two routes.
    Given I set variable "mcpEndpoint" to "${baseUrl}/"
    Given I set variable "healthEndpoint" to "${baseUrl}/health"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: All scenarios -- understanding the MCP endpoint surface before
  # scanning. The MCP server has a minimal surface (POST / and GET /health)
  # but the spider helps ZAP discover response patterns and error shapes.
  # ===========================================================================

  Scenario: Spider discovers MCP endpoint attack surface
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers health endpoint attack surface
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- MCP JSON-RPC Endpoint (POST /)
  # Maps to: All authenticated tool operations (knowledge.create, search, get,
  #          update, relate, traverse) plus authentication failures (401)
  # Checks: Information leakage in error responses, insecure headers, cookie
  #          issues, server version disclosure, MIME type handling
  # ===========================================================================

  Scenario: Passive scan on MCP endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Health Endpoint (GET /health)
  # Maps to: "Health check endpoint is accessible without auth"
  # Checks: The unauthenticated health endpoint should not leak server
  #          internals, stack traces, or version info beyond what is intended
  # ===========================================================================

  Scenario: Passive scan on health endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- SQL Injection
  # Maps to: knowledge.create (title, body, category, tags fields),
  #          knowledge.search (query, category, tags params),
  #          knowledge.get (entry ID param),
  #          knowledge.update (ID, title, body, category, tags fields),
  #          knowledge.relate (from_id, to_id, type fields),
  #          knowledge.traverse (start ID, relationship type params)
  # All user-supplied tool parameters in JSON-RPC params are potential
  # injection vectors that interact with the database.
  # ===========================================================================

  Scenario: No SQL Injection on MCP endpoint
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on health endpoint
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Site Scripting (XSS)
  # Maps to: knowledge.create (title, body stored and later retrieved via get),
  #          knowledge.search (query param reflected in results),
  #          knowledge.update (title, body updated and retrievable)
  # Knowledge entries store user-supplied content that is returned in API
  # responses -- potential for stored XSS if content is rendered in a UI.
  # ===========================================================================

  Scenario: No Cross-Site Scripting on MCP endpoint
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on health endpoint
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Path Traversal
  # Maps to: knowledge.get (entry ID), knowledge.traverse (start entry ID),
  #          knowledge.relate (from_id, to_id)
  # Covers: ID parameters could be crafted as ../../etc/passwd if the server
  #         uses IDs in file system paths or improperly validates UUID format
  # ===========================================================================

  Scenario: No path traversal on MCP endpoint
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Remote Code Execution
  # Maps to: knowledge.create (body field could contain crafted payloads),
  #          knowledge.update (body field), knowledge.search (query param)
  # Covers: User-controlled input in JSON-RPC params that may be passed to
  #          system-level operations (e.g., search indexing, text processing)
  # ===========================================================================

  Scenario: No remote code execution on MCP endpoint
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN -- Full MCP Application
  # Maps to: All scenarios combined -- deep active scan across both endpoints
  # to catch any vulnerability class not covered by individual checks
  # ===========================================================================

  Scenario: Comprehensive active scan on MCP endpoint finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I spider "${healthEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # BASELINE SCAN -- Quick Combined Spider + Passive
  # Maps to: Overall MCP server health check for each endpoint
  # Baseline = spider + passive scan combined; good for CI/CD pipelines
  # ===========================================================================

  Scenario: Baseline scan on MCP endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${mcpEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on health endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS -- API Response Hardening
  # Maps to: All MCP responses -- every response (200, 401, error) should
  #          include proper security headers to prevent MIME-sniffing,
  #          clickjacking, and enforce content policies.
  # NOTE: checkSecurityHeaders sends a GET request. The health endpoint
  #       responds to GET; the MCP endpoint may return an error on GET but
  #       should still include security headers in the response.
  # ===========================================================================

  Scenario: Health endpoint returns proper security headers
    When I check "${healthEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: MCP endpoint returns proper security headers
    When I check "${mcpEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test
  # environment because the MCP server runs over plain HTTP on port 4007.
  # In staging/production, SSL certificate checks should be added:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://mcp.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 90 days
  # ===========================================================================

  # ===========================================================================
  # SECURITY REPORTING -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan suite
  # covering the MCP endpoint and health check
  # ===========================================================================

  Scenario: Generate security audit report for Knowledge MCP server
    Given a new ZAP session
    When I spider "${mcpEndpoint}"
    And I spider "${healthEndpoint}"
    And I run a passive scan on "${mcpEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    And I run an active scan on "${mcpEndpoint}"
    And I run an active scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/knowledge-mcp-security-audit.html"
    And I save the security report as JSON to "reports/knowledge-mcp-security-audit.json"
