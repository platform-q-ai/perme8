@security @queue @warm-only
Feature: Secure warm-start preparation for fresh containers
  As a security auditor
  I want warm-start queue endpoints scanned for auth and container security weaknesses
  So that container preparation cannot be bypassed or manipulated

  Background:
    Given a new ZAP session
    When I spider "http://localhost:5007/internal/sessions"
    Then the spider should find at least 1 URLs

  Scenario: Unauthenticated user cannot trigger queue promotion
    When I run an active scan on "http://localhost:5007/internal/sessions/queue/promote"
    Then there should be no alerts of type "Authentication Bypass"
    And there should be no alerts of type "Missing Authentication for Critical Function"

  Scenario: Unauthenticated user cannot trigger warmup preparation
    When I run an active scan on "http://localhost:5007/internal/sessions/queue/warmup"
    Then there should be no alerts of type "Authentication Bypass"
    And there should be no alerts of type "Missing Authentication for Critical Function"

  Scenario: Queue endpoints serve appropriate security headers
    When I check "http://localhost:5007/internal/sessions" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And alerts should not exceed risk level "Medium"
