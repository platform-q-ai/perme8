@browser @sessions @pr-tab
Feature: Session PR tab for internal code review
  As a user reviewing an internal pull request from the sessions dashboard
  I want a dedicated PR tab in the session detail panel
  So that I can inspect diffs and complete reviews without leaving Perme8

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions?ticket=506"
    And I wait for network idle
    And I wait for "[role='tablist']" to be visible

  # Browser PR-tab scenarios are temporarily disabled.
  # The PR tab remains covered by LiveView tests in
  # `apps/agents_web/test/live/dashboard/index_pr_tab_test.exs`.
