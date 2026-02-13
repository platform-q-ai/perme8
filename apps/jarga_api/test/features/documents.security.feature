@security
Feature: Document API Security Baseline
  As a security engineer
  I want to verify the Document API endpoints are free from common vulnerabilities
  So that document data, API keys, and workspace isolation are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL)
    Given I set variable "docCreateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents"
    Given I set variable "docShowEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    Given I set variable "projectDocEndpoint" to "${baseUrl}/api/workspaces/product-team/projects/q1-launch/documents"
    Given I set variable "crossWorkspaceEndpoint" to "${baseUrl}/api/workspaces/engineering/documents"

  # ---------------------------------------------------------------------------
  # Attack Surface Discovery
  # Maps to: all scenarios -- understanding the full API surface before scanning
  # ---------------------------------------------------------------------------

  Scenario: Spider discovers document API attack surface
    Given a new ZAP session
    When I spider "${baseUrl}/api/workspaces/product-team/documents"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers project-scoped document endpoints
    Given a new ZAP session
    When I spider "${projectDocEndpoint}"
    Then the spider should find at least 1 URLs

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Document Create Endpoint (POST)
  # Maps to: Create document scenarios (default visibility, public, private,
  #          invalid data, unauthorized workspace, viewer role, owner, editor)
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on document creation endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I run a passive scan on "${docCreateEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  Scenario: Passive scan on project document creation endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${projectDocEndpoint}"
    And I run a passive scan on "${projectDocEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Document Retrieve Endpoint (GET)
  # Maps to: Retrieve document scenarios (by slug, cross-workspace, shared doc,
  #          project doc, private doc access, not found, revoked/invalid key)
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on document retrieval endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${docShowEndpoint}"
    And I run a passive scan on "${docShowEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- SQL Injection
  # Maps to: All endpoints that accept user input (slug parameters in URLs,
  #          JSON body with title/content/visibility fields)
  # Covers: API key without workspace access, cross-workspace isolation,
  #         create with invalid data, non-existent project/document
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on document creation endpoint
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I run an active scan on "${docCreateEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on document retrieval endpoint
    Given a new ZAP session
    When I spider "${docShowEndpoint}"
    And I run an active scan on "${docShowEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on project document endpoint
    Given a new ZAP session
    When I spider "${projectDocEndpoint}"
    And I run an active scan on "${projectDocEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Site Scripting (XSS)
  # Maps to: Create document scenarios where title/content are stored and later
  #          retrieved -- potential for stored XSS if content is rendered
  # Covers: Create with various content, retrieve document with content
  # ---------------------------------------------------------------------------

  Scenario: No Cross-Site Scripting on document creation endpoint
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I run an active scan on "${docCreateEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on document retrieval endpoint
    Given a new ZAP session
    When I spider "${docShowEndpoint}"
    And I run an active scan on "${docShowEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Additional Injection Vectors
  # Maps to: Invalid data scenarios, non-existent project/document paths
  # Covers: Path traversal via slug params, command injection via JSON fields
  # ---------------------------------------------------------------------------

  Scenario: No path traversal on document retrieval endpoint
    Given a new ZAP session
    When I spider "${docShowEndpoint}"
    And I run an active scan on "${docShowEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No remote code execution on document creation endpoint
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I run an active scan on "${docCreateEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Workspace Isolation
  # Maps to: "API key without workspace access cannot create document",
  #          "API key cannot access document in workspace it doesn't have access to"
  # Tests: Scanning the cross-workspace endpoint for authorization bypass vulns
  # ---------------------------------------------------------------------------

  Scenario: No authorization bypass on cross-workspace document access
    Given a new ZAP session
    When I spider "${crossWorkspaceEndpoint}"
    And I run an active scan on "${crossWorkspaceEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ---------------------------------------------------------------------------
  # Comprehensive Active Scan -- Full Document API
  # Maps to: All scenarios combined -- deep active scan across all endpoints
  # ---------------------------------------------------------------------------

  Scenario: Comprehensive active scan on document API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I spider "${docShowEndpoint}"
    And I spider "${projectDocEndpoint}"
    And I run an active scan on "${docCreateEndpoint}"
    And I run an active scan on "${docShowEndpoint}"
    And I run an active scan on "${projectDocEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Baseline Scan -- Quick Combined Spider + Passive
  # Maps to: Overall document API health check (all CRUD and retrieval scenarios)
  # ---------------------------------------------------------------------------

  Scenario: Baseline scan on document create endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${docCreateEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on document retrieval endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${docShowEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on project document endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${projectDocEndpoint}"
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

  Scenario: Document retrieval endpoint returns proper security headers
    When I check "${docShowEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Workspace endpoint returns proper security headers
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

  Scenario: Generate security audit report for document API
    Given a new ZAP session
    When I spider "${docCreateEndpoint}"
    And I spider "${docShowEndpoint}"
    And I spider "${projectDocEndpoint}"
    And I run a passive scan on "${docCreateEndpoint}"
    And I run a passive scan on "${docShowEndpoint}"
    And I run a passive scan on "${projectDocEndpoint}"
    And I run an active scan on "${docCreateEndpoint}"
    And I run an active scan on "${docShowEndpoint}"
    And I run an active scan on "${projectDocEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/document-api-security-audit.html"
    And I save the security report as JSON to "reports/document-api-security-audit.json"

  # ===========================================================================
  # PATCH /api/workspaces/:workspace_slug/documents/:slug -- Document Updates
  # ===========================================================================
  #
  # The PATCH endpoint accepts user-controlled JSON body fields (title, content,
  # visibility, content_hash) and slug parameters in the URL path. These are all
  # potential injection vectors. The content_hash field (SHA-256 hex) and slug
  # parameters are especially interesting for injection attacks. Optimistic
  # concurrency control via content_hash introduces additional error responses
  # (409, 422) that should not leak sensitive information.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Attack Surface Discovery -- Document Update Endpoint (PATCH)
  # Maps to: All PATCH scenarios -- discovering the update endpoint surface
  # ---------------------------------------------------------------------------

  Scenario: Spider discovers document update API attack surface
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    Then the spider should find at least 1 URLs

  # ---------------------------------------------------------------------------
  # Passive Vulnerability Scanning -- Document Update Endpoint (PATCH)
  # Maps to: Update title, visibility, content, title+content together
  # Checks: Information leakage, insecure headers, cookie issues in responses
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on document update endpoint finds no high-risk issues
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run a passive scan on "${docUpdateEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- SQL Injection on Update Endpoint
  # Maps to: Update content with correct/stale content_hash, update title,
  #          update visibility, update non-existent document
  # Covers: Slug params in URL path (:workspace_slug, :slug) and JSON body
  #         fields (title, content, visibility, content_hash) are all tested
  #         for SQL injection payloads
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on document update endpoint
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Cross-Site Scripting (XSS) on Update
  # Maps to: Update title, update content -- both fields are stored and later
  #          retrieved via GET, creating a stored XSS risk if not sanitized
  # Covers: Title and content fields in PATCH request body
  # ---------------------------------------------------------------------------

  Scenario: No Cross-Site Scripting on document update endpoint
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Path Traversal on Update Endpoint
  # Maps to: Update non-existent document, cannot update another user's doc
  # Covers: Slug parameters (:workspace_slug, :slug) in the URL path --
  #         attackers may attempt ../../etc/passwd style traversal via slugs
  # ---------------------------------------------------------------------------

  Scenario: No path traversal on document update endpoint
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ---------------------------------------------------------------------------
  # Active Vulnerability Scanning -- Command Injection on Update Endpoint
  # Maps to: Update content, update title -- content_hash (SHA-256 string)
  #          could be crafted as a shell command if improperly handled
  # Covers: All JSON body fields (title, content, visibility, content_hash)
  # ---------------------------------------------------------------------------

  Scenario: No remote code execution on document update endpoint
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ---------------------------------------------------------------------------
  # Baseline Scan -- Document Update Endpoint
  # Maps to: Overall PATCH endpoint health (spider + passive combined)
  # ---------------------------------------------------------------------------

  Scenario: Baseline scan on document update endpoint passes
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I run a baseline scan on "${docUpdateEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ---------------------------------------------------------------------------
  # Comprehensive Active Scan -- Document Update Endpoint
  # Maps to: All PATCH scenarios combined -- deep active scan with full
  #          assertion coverage for the update endpoint
  # ---------------------------------------------------------------------------

  Scenario: Comprehensive active scan on document update endpoint finds no high-risk vulnerabilities
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I store the alerts as "updateEndpointAlerts"
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Security Reporting -- Document Update Endpoint Audit
  # Maps to: Compliance requirement -- dedicated audit report for PATCH endpoint
  # Includes: Spider, passive scan, active scan, all assertions, report output
  # ---------------------------------------------------------------------------

  Scenario: Generate security audit report for document update API
    Given a new ZAP session
    Given I set variable "docUpdateEndpoint" to "${baseUrl}/api/workspaces/product-team/documents/product-spec"
    When I spider "${docUpdateEndpoint}"
    And I run a passive scan on "${docUpdateEndpoint}"
    And I run an active scan on "${docUpdateEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/document-update-api-security-audit.html"
    And I save the security report as JSON to "reports/document-update-api-security-audit.json"
