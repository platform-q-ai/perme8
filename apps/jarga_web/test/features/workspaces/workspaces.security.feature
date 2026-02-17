@security
Feature: Workspace Management Security Baseline
  As a security engineer
  I want to verify the Workspace management LiveView pages are free from common vulnerabilities
  So that workspace data, member invitations, role assignments, and slug-based routing are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (security adapter uses http.baseURL)
    Given I set variable "workspaceListPage" to "${baseUrl}/app/workspaces"
    Given I set variable "workspaceNewPage" to "${baseUrl}/app/workspaces/new"
    Given I set variable "workspaceShowPage" to "${baseUrl}/app/workspaces/product-team"
    Given I set variable "workspaceEditPage" to "${baseUrl}/app/workspaces/product-team/edit"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: All LiveView pages -- understanding the full UI surface before
  # scanning. Jarga Web is a Phoenix LiveView app so we spider each workspace
  # management page to discover forms, links, and dynamic endpoints.
  # ===========================================================================

  Scenario: Spider discovers workspace list page attack surface
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers workspace create page attack surface
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers workspace show page attack surface
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers workspace edit page attack surface
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Public Pages
  # Maps to: Workspace list page (accessible after login, but publicly routable)
  # Checks: Information leakage in workspace cards, insecure cookie settings,
  #          missing security headers, session token exposure
  # ===========================================================================

  # NOTE: Two ZAP false-positive alert families are excluded from passive scans:
  # - "CSP:" -- LiveView requires 'unsafe-inline' for script-src; ZAP flags this
  # - "Absence of Anti-CSRF" -- LiveView uses meta-tag CSRF tokens, not hidden
  #   form fields; ZAP's spider doesn't see the JS-injected tokens
  Scenario: Passive scan on workspace list page finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    And I run a passive scan on "${workspaceListPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Authenticated Pages
  # Maps to: Workspace create, show (with members modal), edit pages
  # Checks: Session handling, cookie security, redirect behavior for
  #          unauthenticated access (should redirect to login, not leak data),
  #          role-based access control enforcement (non-members get redirected)
  # ===========================================================================

  Scenario: Passive scan on workspace create page finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    And I run a passive scan on "${workspaceNewPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on workspace show page finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run a passive scan on "${workspaceShowPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on workspace edit page finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run a passive scan on "${workspaceEditPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- SQL Injection
  # Maps to: Workspace create form (name/description/color fields), Edit form
  #          (name/description/color fields), Show page (slug URL parameter),
  #          Edit page (slug URL parameter), Invite member form (email field)
  # The :slug and :workspace_slug URL parameters are highest risk because they
  # directly map to database lookups. Form fields (name, description, email)
  # are also injection vectors that interact with Ecto queries.
  # ===========================================================================

  Scenario: No SQL Injection on workspace list page
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    And I run an active scan on "${workspaceListPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on workspace create page
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    And I run an active scan on "${workspaceNewPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on workspace show page
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run an active scan on "${workspaceShowPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on workspace edit page
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Site Scripting (XSS)
  # Maps to: Workspace create form (name/description stored and displayed on
  #          list + show pages), Edit form (name/description updated and
  #          re-rendered), Show page (workspace name/description displayed,
  #          member names/emails rendered in modal), Invite form (email
  #          reflected in member list after invitation)
  # LiveView renders user input in templates -- stored XSS risk if not escaped.
  # The name and description fields are particularly high-risk because they are
  # stored and displayed across multiple pages (cards, show, edit).
  # ===========================================================================

  Scenario: No Cross-Site Scripting on workspace list page
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    And I run an active scan on "${workspaceListPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on workspace create page
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    And I run an active scan on "${workspaceNewPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on workspace show page
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run an active scan on "${workspaceShowPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on workspace edit page
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Path Traversal
  # Maps to: Workspace show page (:slug URL parameter), Workspace edit page
  #          (:workspace_slug URL parameter)
  # Covers: Slug parameters in URLs could be crafted as ../../etc/passwd
  #          if improperly validated before database lookup or file operations.
  #          The list and create pages have no URL parameters so are excluded.
  # ===========================================================================

  Scenario: No path traversal on workspace show page
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run an active scan on "${workspaceShowPage}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on workspace edit page
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Remote Code Execution
  # Maps to: Workspace create form (name/description/color fields passed to
  #          server-side processing), Edit form (same fields updated),
  #          Show page invite form (email field may trigger email sending),
  #          Show page role change (role value processed server-side)
  # Covers: User-controlled input in form fields that may be passed to
  #          system-level operations (e.g., email sending for invitations,
  #          slug generation from workspace name)
  # ===========================================================================

  Scenario: No remote code execution on workspace create page
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    And I run an active scan on "${workspaceNewPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on workspace edit page
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on workspace show page
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run an active scan on "${workspaceShowPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- CSRF Protection
  # Maps to: POST /app/workspaces (create workspace form submission),
  #          PUT /app/workspaces/:slug (edit workspace form submission),
  #          POST invite member (email + role in members modal),
  #          PATCH role change (phx-change event on role select),
  #          DELETE remove member (button with confirm dialog),
  #          DELETE /app/workspaces/:slug (delete workspace with confirm)
  # Phoenix LiveView forms include CSRF tokens by default. Active scanning
  # verifies the server rejects requests with missing or tampered tokens.
  # ===========================================================================

  Scenario: No CSRF vulnerabilities on workspace create page
    Given a new ZAP session
    When I spider "${workspaceNewPage}"
    And I run an active scan on "${workspaceNewPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  Scenario: No CSRF vulnerabilities on workspace edit page
    Given a new ZAP session
    When I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  Scenario: No CSRF vulnerabilities on workspace show page
    Given a new ZAP session
    When I spider "${workspaceShowPage}"
    And I run an active scan on "${workspaceShowPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN -- Full Workspace Management Application
  # Maps to: All scenarios combined -- deep active scan across all workspace
  # management pages to catch any vulnerability class. Covers the public
  # workspace list as well as authenticated create, show, and edit pages.
  # ===========================================================================

  Scenario: Comprehensive active scan on workspace pages finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    And I spider "${workspaceNewPage}"
    And I spider "${workspaceShowPage}"
    And I spider "${workspaceEditPage}"
    And I run an active scan on "${workspaceListPage}"
    And I run an active scan on "${workspaceNewPage}"
    And I run an active scan on "${workspaceShowPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then no high risk alerts should be found
    And I store the alerts as "workspaceScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # BASELINE SCAN -- Quick Combined Spider + Passive
  # Maps to: Overall Workspace app health check for each endpoint
  # Baseline = spider + passive scan combined; good for CI/CD pipelines
  # ===========================================================================

  Scenario: Baseline scan on workspace list page passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceListPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on workspace create page passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceNewPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on workspace show page passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceShowPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on workspace edit page passes
    Given a new ZAP session
    When I run a baseline scan on "${workspaceEditPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS -- Response Hardening
  # Maps to: All pages must return proper security headers to prevent
  #          clickjacking (X-Frame-Options), MIME sniffing (X-Content-Type-Options),
  #          and enforce content policies (CSP, HSTS, Referrer-Policy,
  #          Permissions-Policy)
  # NOTE: checkSecurityHeaders sends a GET request. We test all four workspace
  #       pages. Phoenix pipelines apply headers uniformly, so coverage of the
  #       list and create pages validates the :browser pipeline; show and edit
  #       pages validate the :authenticated pipeline with slug-based routing.
  # ===========================================================================

  Scenario: Workspace list page returns proper security headers
    When I check "${workspaceListPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Workspace create page returns proper security headers
    When I check "${workspaceNewPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Workspace show page returns proper security headers
    When I check "${workspaceShowPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Workspace edit page returns proper security headers
    When I check "${workspaceEditPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test environment
  # because the test server runs over plain HTTP on port 4002. In staging/
  # production, SSL certificate checks should be added:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://jarga.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 90 days
  # ===========================================================================

  # ===========================================================================
  # SECURITY REPORTING -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan suite
  # covering all Workspace management endpoints (list, create, show with members
  # modal and invite/role/remove actions, edit, delete)
  # ===========================================================================

  Scenario: Generate security audit report for Workspace management
    Given a new ZAP session
    When I spider "${workspaceListPage}"
    And I spider "${workspaceNewPage}"
    And I spider "${workspaceShowPage}"
    And I spider "${workspaceEditPage}"
    And I run a passive scan on "${workspaceListPage}"
    And I run a passive scan on "${workspaceNewPage}"
    And I run a passive scan on "${workspaceShowPage}"
    And I run a passive scan on "${workspaceEditPage}"
    And I run an active scan on "${workspaceListPage}"
    And I run an active scan on "${workspaceNewPage}"
    And I run an active scan on "${workspaceShowPage}"
    And I run an active scan on "${workspaceEditPage}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And there should be no alerts of type "Cross-Site Request Forgery"
    And I should see the alert details
    When I save the security report to "reports/workspaces-security-audit.html"
    And I save the security report as JSON to "reports/workspaces-security-audit.json"
