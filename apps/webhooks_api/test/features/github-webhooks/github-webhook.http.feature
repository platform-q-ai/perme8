@http
Feature: GitHub Webhook Receiver API
  As the perme8 platform
  I want to receive and process GitHub App webhook events over HTTP
  So that PR lifecycle automations can be triggered reliably

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  Scenario: GitHub sends a pull_request opened event
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-pr-opened}"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-pr-opened-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "opened",
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be true
    And the response body path "$.dispatch.type" should equal "pr_review"

  Scenario: GitHub sends a pull_request synchronize event (new commits pushed)
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-pr-synchronize}"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-pr-synchronize-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "synchronize",
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be true
    And the response body path "$.dispatch.type" should equal "pr_review"

  Scenario: GitHub sends a pull_request_review event with request_changes
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-pr-review-changes-requested}"
    And I set header "X-GitHub-Event" to "pull_request_review"
    And I set header "X-GitHub-Delivery" to "delivery-pr-review-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "submitted",
        "review": {"state": "changes_requested"},
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "reviewer-user"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be true
    And the response body path "$.dispatch.type" should equal "comment_addressing"

  Scenario: GitHub sends an issue_comment event on a PR
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-issue-comment-created}"
    And I set header "X-GitHub-Event" to "issue_comment"
    And I set header "X-GitHub-Delivery" to "delivery-issue-comment-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "created",
        "issue": {
          "number": 42,
          "pull_request": {"url": "https://api.github.com/repos/platform-q-ai/perme8/pulls/42"}
        },
        "comment": {"body": "Please address review feedback"},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "maintainer-user"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be true
    And the response body path "$.dispatch.type" should equal "comment_addressing"

  Scenario: GitHub sends a merge_group event for merge queue entry
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-merge-group-checks-requested}"
    And I set header "X-GitHub-Event" to "merge_group"
    And I set header "X-GitHub-Delivery" to "delivery-merge-group-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "checks_requested",
        "merge_group": {"head_sha": "abc123def456"},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be true
    And the response body path "$.dispatch.type" should equal "merge_queue"

  Scenario: Webhook with invalid HMAC signature is rejected
    Given I set header "X-Hub-Signature-256" to "sha256=invalid-signature-value"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-invalid-signature-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "opened",
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  Scenario: Webhook with missing signature header is rejected
    Given I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-missing-signature-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "opened",
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  Scenario: Unhandled GitHub event type is acknowledged but not processed
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-push-event}"
    And I set header "X-GitHub-Event" to "push"
    And I set header "X-GitHub-Delivery" to "delivery-push-ignored-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "ref": "refs/heads/main",
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be false

  Scenario: PR event from the bot itself is ignored to prevent loops
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-pr-opened-bot-sender}"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-bot-sender-ignored-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "opened",
        "pull_request": {"number": 42},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "perme8[bot]"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.dispatched" should be false

  Scenario: Webhook with malformed JSON body is rejected
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-malformed-json}"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-malformed-json-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {this is not valid json
      """
    Then the response status should be 400
    And the response body should be valid JSON

  Scenario: All received webhook events are logged for audit purposes
    Given I set header "X-Hub-Signature-256" to "${valid-github-signature-pr-opened-audit}"
    And I set header "X-GitHub-Event" to "pull_request"
    And I set header "X-GitHub-Delivery" to "delivery-audit-001"
    When I POST raw to "${github-webhook-endpoint}" with body:
      """
      {
        "action": "opened",
        "pull_request": {"number": 99},
        "repository": {"full_name": "platform-q-ai/perme8"},
        "sender": {"login": "octocat"}
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.audit.event_type" should equal "pull_request"
    And the response body path "$.audit.delivery_id" should equal "delivery-audit-001"
    And the response body path "$.audit.result" should exist
