@browser @sessions @auth
Feature: Cross-App Authentication for Sessions
  As a user
  I want to be redirected to the Identity login page when unauthenticated
  So that I can log in and be returned to the sessions page automatically

  # agents_web delegates authentication to the Identity app. When an
  # unauthenticated user visits /sessions, they are redirected to
  # Identity's login page with a ?return_to= parameter. After successful
  # login, Identity redirects back to agents_web.
  #
  # Both apps share the _identity_key session cookie (same cookie key,
  # signing salt, and secret_key_base) so the session is portable across
  # endpoints on the same domain (localhost).

  # ---------------------------------------------------------------------------
  # Unauthenticated Redirect
  # ---------------------------------------------------------------------------

  Scenario: Unauthenticated user is redirected to Identity login with return_to
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the URL to contain "/users/log-in"
    Then the URL should contain "return_to"
    And I should see "Log in"

  # ---------------------------------------------------------------------------
  # Login Return Flow
  # ---------------------------------------------------------------------------

  Scenario: After login, user is redirected back to sessions page
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the URL to contain "/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the URL to contain "/sessions"
    And I wait for network idle
    Then the URL should contain "/sessions"
    And I should see "Sessions"
    And I should see "Run coding tasks in containers"

  # ---------------------------------------------------------------------------
  # Failed Login
  # ---------------------------------------------------------------------------

  Scenario: Failed login stays on Identity login page with error
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the URL to contain "/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "WrongPassword123!"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for 2 seconds
    Then I should see "Invalid email or password"
    And the URL should contain "/users/log-in"
