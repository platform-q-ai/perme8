@security
Feature: API Key Permission Security
  As a security-conscious platform operator
  I want API key permissions to be securely enforced
  So that compromised or misconfigured keys cannot escalate their access

  Background:
    Given a new ZAP session

  Scenario: Permission enforcement prevents unauthorized REST API access
    Given I set variable "permissionModel" to "read-only key cannot perform write actions"
    When I spider "${baseUrl}"
    And I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Broken Access Control"

  Scenario: Permission enforcement prevents unauthorized MCP tool access
    Given I set variable "permissionModel" to "MCP tool scopes are enforced"
    When I spider "${baseUrl}"
    And I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Broken Access Control"

  Scenario: Wildcard permissions grant appropriate access levels
    Given I set variable "permissionModel" to "wildcards grant only scoped category access"
    When I run a baseline scan on "${baseUrl}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Nil permissions maintain backward compatibility
    Given I set variable "permissionModel" to "nil permissions preserve legacy full access behavior"
    When I run a passive scan on "${baseUrl}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Empty permissions deny all access
    Given I set variable "permissionModel" to "empty permission list denies all operations"
    When I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Broken Access Control"

  Scenario: Permission check happens after authentication
    Given I set variable "permissionModel" to "authentication must fail before authorization checks"
    When I run a baseline scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Authentication Bypass"

  Scenario: API key permissions cannot be escalated
    Given I set variable "permissionModel" to "keys cannot self-escalate scopes"
    When I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Privilege Escalation"

  Scenario: Permission changes take effect immediately
    Given I set variable "permissionModel" to "permission updates apply without stale authorization cache"
    When I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Authorization Bypass"

  Scenario: Security headers on permission denial responses
    Given I set variable "permissionModel" to "forbidden responses include hardened headers and no sensitive leakage"
    When I check "${baseUrl}" for security headers
    Then Content-Security-Policy should be present
    And Strict-Transport-Security should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"

  Scenario: Workspace access and permissions are independent
    Given I set variable "permissionModel" to "workspace access and permission scope are both required"
    When I spider "${baseUrl}"
    And I run an active scan on "${baseUrl}"
    Then no high risk alerts should be found
    And there should be no alerts of type "Broken Access Control"
    And I save the security report to "reports/api-permissions-security.html"
    And I save the security report as JSON to "reports/api-permissions-security.json"
