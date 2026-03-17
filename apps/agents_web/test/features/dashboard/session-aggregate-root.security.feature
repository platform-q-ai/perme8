@security @sessions @aggregate-root
Feature: Session aggregate root security
  As a security auditor
  I want session management endpoints scanned for auth and access control weaknesses
  So that users cannot access other users' data and the system follows security best practices

  Background:
    Given a new ZAP session
    When I spider "${baseUrl}/sessions"
    Then the spider should find at least 1 URLs

  Scenario: Sessions page has no high risk vulnerabilities
    When I run an active scan on "${baseUrl}/sessions"
    Then no high risk alerts should be found

  Scenario: Sessions page has no authentication bypass vulnerabilities
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Authentication Bypass"
    And there should be no alerts of type "Missing Authentication for Critical Function"

  Scenario: Sessions page has no access control vulnerabilities
    When I run an active scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Insecure Direct Object Reference"
    And there should be no alerts of type "Broken Access Control"

  Scenario: Sessions page serves appropriate security headers
    When I check "${baseUrl}/sessions" for security headers
    Then Content-Security-Policy should be present
    And X-Frame-Options should be set to "DENY"
    And the security headers should include "X-Content-Type-Options"

  Scenario: Session API responses do not expose sensitive information
    When I run a passive scan on "${baseUrl}/sessions"
    Then there should be no alerts of type "Information Disclosure"
    And alerts should not exceed risk level "Medium"
