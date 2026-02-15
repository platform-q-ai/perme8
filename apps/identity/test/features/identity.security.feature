@security
Feature: Identity Application Security Baseline
  As a security engineer
  I want to verify the Identity authentication endpoints are free from common vulnerabilities
  So that user credentials, sessions, password reset tokens, and API keys are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (security adapter uses http.baseURL)
    Given I set variable "loginPage" to "${baseUrl}/users/log-in"
    Given I set variable "registerPage" to "${baseUrl}/users/register"
    Given I set variable "resetPasswordPage" to "${baseUrl}/users/reset-password"
    Given I set variable "resetPasswordTokenPage" to "${baseUrl}/users/reset-password/test-token"
    Given I set variable "settingsPage" to "${baseUrl}/users/settings"
    Given I set variable "apiKeysPage" to "${baseUrl}/users/api-keys"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: All LiveView pages -- understanding the full UI surface before
  # scanning. Identity is a Phoenix LiveView app so we use the ajax spider
  # for JavaScript-heavy pages alongside the standard spider.
  # ===========================================================================

  Scenario: Spider discovers login page attack surface
    Given a new ZAP session
    When I spider "${loginPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers registration page attack surface
    Given a new ZAP session
    When I spider "${registerPage}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers password reset page attack surface
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Authentication Endpoints
  # Maps to: Login (email+password, magic link), Registration, Logout
  # Checks: Information leakage in error messages, insecure cookie settings,
  #          missing security headers, CSRF token exposure
  # ===========================================================================

  # NOTE: Two ZAP false-positive alert families are excluded from passive scans:
  # - "CSP:" -- LiveView requires 'unsafe-inline' for script-src; ZAP flags this
  # - "Absence of Anti-CSRF" -- LiveView uses meta-tag CSRF tokens, not hidden
  #   form fields; ZAP's spider doesn't see the JS-injected tokens
  Scenario: Passive scan on login page finds no high-risk issues
    Given a new ZAP session
    When I spider "${loginPage}"
    And I run a passive scan on "${loginPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on registration page finds no high-risk issues
    Given a new ZAP session
    When I spider "${registerPage}"
    And I run a passive scan on "${registerPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on password reset page finds no high-risk issues
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    And I run a passive scan on "${resetPasswordPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on reset password token page finds no high-risk issues
    Given a new ZAP session
    When I spider "${resetPasswordTokenPage}"
    And I run a passive scan on "${resetPasswordTokenPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Authenticated Pages
  # Maps to: User settings, API key management
  # Checks: Session handling, cookie security, redirect behavior for
  #          unauthenticated access (should redirect to login, not leak data)
  # ===========================================================================

  Scenario: Passive scan on settings page finds no high-risk issues
    Given a new ZAP session
    When I spider "${settingsPage}"
    And I run a passive scan on "${settingsPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  Scenario: Passive scan on API keys page finds no high-risk issues
    Given a new ZAP session
    When I spider "${apiKeysPage}"
    And I run a passive scan on "${apiKeysPage}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found excluding "CSP:, Absence of Anti-CSRF"
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- SQL Injection
  # Maps to: Login form (email/password fields), Registration form
  #          (email/password/name fields), Password reset (email field),
  #          Reset password token (token URL parameter, password fields)
  # These are the highest-risk injection points because they directly handle
  # user-supplied credentials that interact with the database.
  # ===========================================================================

  Scenario: No SQL Injection on login page
    Given a new ZAP session
    When I spider "${loginPage}"
    And I run an active scan on "${loginPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on registration page
    Given a new ZAP session
    When I spider "${registerPage}"
    And I run an active scan on "${registerPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on password reset page
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordPage}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on reset password token page
    Given a new ZAP session
    When I spider "${resetPasswordTokenPage}"
    And I run an active scan on "${resetPasswordTokenPage}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Site Scripting (XSS)
  # Maps to: Login form (email field reflected in error messages), Registration
  #          form (name/email fields stored and displayed), Password reset
  #          (email field reflected in flash messages)
  # LiveView renders user input in templates -- stored XSS risk if not escaped.
  # ===========================================================================

  Scenario: No Cross-Site Scripting on login page
    Given a new ZAP session
    When I spider "${loginPage}"
    And I run an active scan on "${loginPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on registration page
    Given a new ZAP session
    When I spider "${registerPage}"
    And I run an active scan on "${registerPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on password reset page
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on reset password token page
    Given a new ZAP session
    When I spider "${resetPasswordTokenPage}"
    And I run an active scan on "${resetPasswordTokenPage}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Path Traversal
  # Maps to: Reset password token endpoint (/:token URL parameter),
  #          Settings page, API keys page
  # Covers: Token parameter in URL could be crafted as ../../etc/passwd
  #          if improperly validated before file or DB lookup
  # ===========================================================================

  Scenario: No path traversal on reset password token page
    Given a new ZAP session
    When I spider "${resetPasswordTokenPage}"
    And I run an active scan on "${resetPasswordTokenPage}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on settings page
    Given a new ZAP session
    When I spider "${settingsPage}"
    And I run an active scan on "${settingsPage}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on API keys page
    Given a new ZAP session
    When I spider "${apiKeysPage}"
    And I run an active scan on "${apiKeysPage}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Remote Code Execution
  # Maps to: Registration form (name fields), Password reset (email field),
  #          Reset password token (password fields)
  # Covers: User-controlled input in form fields that may be passed to
  #          system-level operations (e.g., email sending, token generation)
  # ===========================================================================

  Scenario: No remote code execution on login page
    Given a new ZAP session
    When I spider "${loginPage}"
    And I run an active scan on "${loginPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on registration page
    Given a new ZAP session
    When I spider "${registerPage}"
    And I run an active scan on "${registerPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on password reset page
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordPage}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- CSRF Protection
  # Maps to: POST /users/log-in, POST /users/register,
  #          POST /users/reset-password, PUT /users/reset-password/:token,
  #          DELETE /users/log-out
  # Phoenix LiveView forms include CSRF tokens by default. Active scanning
  # verifies the server rejects requests with missing or tampered tokens.
  # ===========================================================================

  Scenario: No CSRF vulnerabilities on login page
    Given a new ZAP session
    When I spider "${loginPage}"
    And I run an active scan on "${loginPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  Scenario: No CSRF vulnerabilities on registration page
    Given a new ZAP session
    When I spider "${registerPage}"
    And I run an active scan on "${registerPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  Scenario: No CSRF vulnerabilities on password reset page
    Given a new ZAP session
    When I spider "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordPage}"
    Then there should be no alerts of type "Cross-Site Request Forgery"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN -- Full Identity Application
  # Maps to: All scenarios combined -- deep active scan across all public-facing
  # authentication endpoints to catch any vulnerability class
  # ===========================================================================

  Scenario: Comprehensive active scan on authentication pages finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${loginPage}"
    And I spider "${registerPage}"
    And I spider "${resetPasswordPage}"
    And I spider "${resetPasswordTokenPage}"
    And I run an active scan on "${loginPage}"
    And I run an active scan on "${registerPage}"
    And I run an active scan on "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordTokenPage}"
    Then no high risk alerts should be found
    And I store the alerts as "authScanAlerts"
    And I should see the alert details

  Scenario: Comprehensive active scan on protected pages finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${settingsPage}"
    And I spider "${apiKeysPage}"
    And I run an active scan on "${settingsPage}"
    And I run an active scan on "${apiKeysPage}"
    Then no high risk alerts should be found
    And I store the alerts as "protectedPagesScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # BASELINE SCAN -- Quick Combined Spider + Passive
  # Maps to: Overall Identity app health check for each endpoint group
  # Baseline = spider + passive scan combined; good for CI/CD pipelines
  # ===========================================================================

  Scenario: Baseline scan on login page passes
    Given a new ZAP session
    When I run a baseline scan on "${loginPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on registration page passes
    Given a new ZAP session
    When I run a baseline scan on "${registerPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on password reset page passes
    Given a new ZAP session
    When I run a baseline scan on "${resetPasswordPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on reset password token page passes
    Given a new ZAP session
    When I run a baseline scan on "${resetPasswordTokenPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on settings page passes
    Given a new ZAP session
    When I run a baseline scan on "${settingsPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on API keys page passes
    Given a new ZAP session
    When I run a baseline scan on "${apiKeysPage}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS -- Response Hardening
  # Maps to: All pages must return proper security headers to prevent
  #          clickjacking (X-Frame-Options), MIME sniffing (X-Content-Type-Options),
  #          and enforce content policies (CSP, HSTS, Referrer-Policy,
  #          Permissions-Policy)
  # NOTE: checkSecurityHeaders sends a GET request. We test all pages that
  #       serve GET routes. Phoenix pipelines apply headers uniformly, so
  #       coverage of the login, register, and reset pages validates the
  #       :browser pipeline; settings and API keys validate the :authenticated
  #       pipeline as well.
  # ===========================================================================

  Scenario: Login page returns proper security headers
    When I check "${loginPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Registration page returns proper security headers
    When I check "${registerPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Password reset page returns proper security headers
    When I check "${resetPasswordPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: Settings page returns proper security headers
    When I check "${settingsPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  Scenario: API keys page returns proper security headers
    When I check "${apiKeysPage}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"
    And the security headers should include "Referrer-Policy"
    And the security headers should include "Permissions-Policy"

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test environment
  # because the test server runs over plain HTTP on port 4001. In staging/
  # production, SSL certificate checks should be added:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://identity.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 90 days
  # ===========================================================================

  # ===========================================================================
  # SECURITY REPORTING -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan suite
  # covering all Identity app endpoints (authentication, registration, password
  # reset, settings, API keys)
  # ===========================================================================

  Scenario: Generate security audit report for Identity application
    Given a new ZAP session
    When I spider "${loginPage}"
    And I spider "${registerPage}"
    And I spider "${resetPasswordPage}"
    And I spider "${resetPasswordTokenPage}"
    And I spider "${settingsPage}"
    And I spider "${apiKeysPage}"
    And I run a passive scan on "${loginPage}"
    And I run a passive scan on "${registerPage}"
    And I run a passive scan on "${resetPasswordPage}"
    And I run a passive scan on "${resetPasswordTokenPage}"
    And I run a passive scan on "${settingsPage}"
    And I run a passive scan on "${apiKeysPage}"
    And I run an active scan on "${loginPage}"
    And I run an active scan on "${registerPage}"
    And I run an active scan on "${resetPasswordPage}"
    And I run an active scan on "${resetPasswordTokenPage}"
    And I run an active scan on "${settingsPage}"
    And I run an active scan on "${apiKeysPage}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And there should be no alerts of type "Cross-Site Request Forgery"
    And I should see the alert details
    When I save the security report to "reports/identity-security-audit.html"
    And I save the security report as JSON to "reports/identity-security-audit.json"
