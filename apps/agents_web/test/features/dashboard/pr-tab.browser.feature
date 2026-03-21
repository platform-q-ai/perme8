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
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "[data-testid='session-with-linked-pr']"
    And I wait for "[role='tablist']" to be visible

  Scenario: PR tab appears when a linked internal PR exists
    Then "[role='tab'][data-tab-id='pr']" should be visible

  Scenario: PR tab does not appear when no linked internal PR exists
    When I click "[data-testid='session-without-linked-pr']"
    And I wait for "[role='tablist']" to be visible
    Then "[role='tab'][data-tab-id='pr']" should not exist

  Scenario: PR tab becomes the active panel from the URL
    Given I navigate to "${baseUrl}/sessions?tab=pr"
    And I wait for network idle
    Then "[role='tab'][data-tab-id='pr'][aria-selected='true']" should be visible
    And the URL should contain "tab=pr"

  Scenario: PR header and description are shown
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    Then "#tabpanel-pr [data-testid='pr-title']" should be visible
    And "#tabpanel-pr [data-testid='pr-status']" should be visible
    And "#tabpanel-pr [data-testid='pr-branches']" should be visible
    And "#tabpanel-pr [data-testid='pr-author-and-timestamps']" should be visible
    And "#tabpanel-pr [data-testid='pr-description']" should be visible

  Scenario: PR tab shows changed files and rendered diffs
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    Then "#tabpanel-pr [data-testid='pr-diff-file']" should exist
    And "#tabpanel-pr [data-testid='pr-diff-code']" should exist
    And I should not see "Syncing PR data from GitHub"

  Scenario: PR tab shows inline review comment threads
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    Then "#tabpanel-pr [data-testid='pr-review-thread']" should exist
    And "#tabpanel-pr [data-testid='pr-review-reply']" should exist
    And "#tabpanel-pr [data-testid='pr-thread-resolved-state']" should exist

  Scenario: Reviewer can add comments and replies
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    And I click "#tabpanel-pr [data-testid='pr-add-inline-comment-button']"
    And I fill "#tabpanel-pr [data-testid='pr-inline-comment-input']" with "Please extract this logic into a helper."
    And I click the "Add comment" button
    Then "#tabpanel-pr [data-testid='pr-review-thread']" should contain text "Please extract this logic into a helper."
    When I fill "#tabpanel-pr [data-testid='pr-reply-input']" with "Good point, I will update this."
    And I click the "Reply" button
    Then "#tabpanel-pr [data-testid='pr-review-thread']" should contain text "Good point, I will update this."

  Scenario: Reviewer can resolve a review thread
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    And I click "#tabpanel-pr [data-testid='pr-resolve-thread-button']"
    Then "#tabpanel-pr [data-testid='pr-review-thread']" should have class "resolved"

  Scenario: Reviewer can submit a review decision
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    And I click "#tabpanel-pr [data-testid='pr-review-decision-approve']"
    And I click the "Submit review" button
    Then "#tabpanel-pr [data-testid='pr-last-review-outcome']" should contain text "Approved"
    When I click "#tabpanel-pr [data-testid='pr-review-decision-request-changes']"
    And I click the "Submit review" button
    Then "#tabpanel-pr [data-testid='pr-last-review-outcome']" should contain text "Changes requested"
    When I click "#tabpanel-pr [data-testid='pr-review-decision-comment']"
    And I click the "Submit review" button
    Then "#tabpanel-pr [data-testid='pr-last-review-outcome']" should contain text "Commented"

  Scenario: PR tab excludes pipeline status
    When I click "[role='tab'][data-tab-id='pr']"
    And I wait for "#tabpanel-pr" to be visible
    Then "#tabpanel-pr [data-testid='pipeline-status']" should not exist
    And "#tabpanel-pr [data-testid='pipeline-stage-widget']" should not exist
