@security
Feature: Notification Security Baseline
  As a security engineer
  I want to verify the notification bell LiveComponent is free from common vulnerabilities
  So that notification data is protected, user-scoped notifications cannot leak across users,
  and state-changing operations (mark-as-read, mark-all-as-read, accept/decline) are safe from attack

  # The NotificationBell is a LiveComponent rendered in the application topbar on
  # every authenticated page. Notifications are strictly user-scoped -- all queries
  # filter by user_id. There is no dedicated notification page; all interactions
  # happen via the bell dropdown in the topbar.
  #
  # Pages that render notification UI:
  #   - Dashboard:       /app
  #   - Workspace show:  /app/workspaces/:slug
  #
  # State-changing operations:
  #   - Mark individual notification as read (phx-click event)
  #   - Mark all notifications as read (phx-click event)
  #   - Accept/decline workspace invitation (delegates to Identity)
  #
  # Notification data fields: type, title, body, data (JSON map), read status.
  # The title and body may contain user-supplied text. The data map may contain
  # workspace IDs and other internal references.

  Background:
    # baseUrl is auto-injected from exo-bdd config (security adapter uses http.baseURL)
    Given I set variable "dashboardPage" to "${baseUrl}/app"
    Given I set variable "workspacePage" to "${baseUrl}/app/workspaces/${productTeamSlug}"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: Generic Scenario "Notification data is user-scoped" and
  #          "Unauthenticated access redirects to login"
  # The notification bell is embedded in every authenticated page. We spider the
  # dashboard and a workspace page to discover the bell dropdown, its links,
  # and any dynamic endpoints exposed by the LiveComponent. This maps the
  # attack surface before running vulnerability scans.
  # ===========================================================================

  Scenario: Spider discovers dashboard notification bell attack surface
    Given a new ZAP session
    When I spider "${dashboardPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers workspace page notification bell attack surface
    Given a new ZAP session
    When I spider "${workspacePage}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING
  # Maps to: Generic Scenarios "Notification data is user-scoped" and
  #          "Unauthenticated access redirects to login"
  # Checks: Information leakage in notification content, insecure cookie settings,
  #          missing security headers, session token exposure, redirect behavior
  #          for unauthenticated access (should redirect to login, not leak data).
  #          User-scoped data isolation is validated by checking that passive
  #          scanning reveals no information disclosure vulnerabilities.
  #
  # NOTE: Two ZAP false-positive alert families are excluded from passive scans:
  # - "CSP:" -- LiveView requires 'unsafe-inline' for script-src and style-src;
  #   ZAP flags this as "CSP: script-src unsafe-inline" and "CSP: style-src unsafe-inline"
  # - "Absence of Anti-CSRF" -- LiveView uses meta-tag CSRF tokens, not hidden
  #   form fields; ZAP's spider doesn't see the JS-injected tokens
  # ===========================================================================

  Scenario: Passive scan on dashboard with notification bell finds no high-risk issues
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I run a passive scan on "${dashboardPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on workspace page with notification bell finds no high-risk issues
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run a passive scan on "${workspacePage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- SQL Injection
  # Maps to: Generic Scenario "No SQL injection on notification queries"
  # Notifications are queried by user_id with Ecto parameterized queries.
  # The dashboard and workspace pages render the notification bell, which
  # triggers notification queries. Active scanning injects SQL payloads into
  # URL parameters, form fields, and cookie values to verify that Ecto's
  # parameterized queries prevent injection.
  # ===========================================================================

  Scenario: No SQL Injection on dashboard with notification bell
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I run an active scan on "${dashboardPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on workspace page with notification bell
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run an active scan on "${workspacePage}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Site Scripting (XSS)
  # Maps to: Generic Scenario "No XSS in notification content"
  # Notification titles and bodies may contain user-supplied text that is
  # rendered in the bell dropdown LiveComponent. Stored XSS is a risk if
  # notification content is not properly escaped by LiveView's template engine.
  # The data map may also contain values rendered in the UI (e.g., workspace
  # names in invitation notifications).
  # ===========================================================================

  Scenario: No Cross-Site Scripting on dashboard with notification bell
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I run an active scan on "${dashboardPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on workspace page with notification bell
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run an active scan on "${workspacePage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Path Traversal
  # Maps to: Workspace page (:slug URL parameter)
  # The workspace page uses a :slug parameter in the URL that could be crafted
  # as ../../etc/passwd if improperly validated. The dashboard has no URL
  # parameters so only the workspace page is tested.
  # ===========================================================================

  Scenario: No path traversal on workspace page with notification bell
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run an active scan on "${workspacePage}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Remote Code Execution
  # Maps to: Pages rendering notification content with dynamic data
  # Notification data includes a JSON map that may be processed server-side.
  # Active scanning verifies that no user-controlled input in the notification
  # rendering pipeline can lead to OS command injection.
  # ===========================================================================

  Scenario: No remote code execution on dashboard with notification bell
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I run an active scan on "${dashboardPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on workspace page with notification bell
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run an active scan on "${workspacePage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- CSRF Protection
  # Maps to: Generic Scenario "No CSRF on notification state-changing operations"
  # State-changing operations in the notification bell:
  #   - Mark individual notification as read (phx-click event)
  #   - Mark all notifications as read (phx-click event)
  #   - Accept/decline workspace invitation (phx-click event, delegates to Identity)
  # Phoenix LiveView forms and events include CSRF tokens by default via
  # meta-tags. Active scanning verifies the server rejects requests with
  # missing or tampered tokens.
  # ===========================================================================

  Scenario: No CSRF vulnerabilities on dashboard with notification bell
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I run an active scan on "${dashboardPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  Scenario: No CSRF vulnerabilities on workspace page with notification bell
    Given a new ZAP session
    When I spider "${workspacePage}"
    And I run an active scan on "${workspacePage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  # ===========================================================================
  # BASELINE SCAN -- Quick Combined Spider + Passive
  # Maps to: Overall notification UI health check for each page
  # Baseline = spider + passive scan combined; good for CI/CD pipelines.
  # Covers the generic scenarios for user-scoped data protection and
  # unauthenticated access redirect by ensuring no high-risk information
  # disclosure or session vulnerabilities are found.
  # ===========================================================================

  Scenario: Baseline scan on dashboard with notification bell passes
    Given a new ZAP session
    When I run a baseline scan on "${dashboardPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on workspace page with notification bell passes
    Given a new ZAP session
    When I run a baseline scan on "${workspacePage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS -- Response Hardening
  # Maps to: Generic Scenario "Notification pages have proper security headers"
  # All pages rendering the notification bell must return proper security headers
  # to prevent clickjacking (X-Frame-Options), MIME sniffing (X-Content-Type-Options),
  # and enforce content policies (CSP, HSTS, Referrer-Policy, Permissions-Policy).
  # The dashboard validates the :authenticated pipeline; the workspace page
  # validates the :authenticated pipeline with slug-based routing.
  # ===========================================================================

  Scenario: Dashboard page with notification bell returns proper security headers
    When I check "${dashboardPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Workspace page with notification bell returns proper security headers
    When I check "${workspacePage}" for security headers
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
  # Maps to: Compliance requirement -- generate audit artifacts after scanning.
  # Uses passive scans only (spider + passive) since individual scenarios above
  # already perform per-page active scans for each vulnerability class. This
  # avoids redundant active scanning while still producing a comprehensive
  # report with header and passive findings.
  # ===========================================================================

  Scenario: Generate security audit report for Notification management
    Given a new ZAP session
    When I spider "${dashboardPage}"
    And I spider "${workspacePage}"
    And I run a passive scan on "${dashboardPage}"
    And I run a passive scan on "${workspacePage}"
    Then no high risk alerts should be found
    And I should see the alert details
    When I save the security report to "reports/notifications-security-audit.html"
    And I save the security report as JSON to "reports/notifications-security-audit.json"
