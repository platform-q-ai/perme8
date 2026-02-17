@browser
Feature: Document Listing
  As a workspace member
  I want to see documents filtered by visibility and project
  So that I can find the documents I need

  # Background data setup (workspaces, users, roles, documents) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #   eve@example.com     - not a member of workspace "product-team"
  #
  # Seeded documents in workspace "product-team":
  #   "Product Spec"           - public (slug: product-spec)
  #   "Shared Doc"             - public, by bob (slug: shared-doc)
  #   "Bobs Private Doc"       - private, by bob (slug: bobs-private-doc)
  #   "Launch Plan"            - public, project: q1-launch (slug: launch-plan)
  #   "Draft Roadmap"          - private (slug: draft-roadmap)
  #   "Private Doc"            - private (slug: private-doc)
  #   "Public Doc"             - public (slug: public-doc)
  #   "Team Guidelines"        - public (slug: team-guidelines)
  #   "Pinned Doc"             - private (slug: pinned-doc)
  #   "Specs"                  - public, project: mobile-app (slug: specs)

  Scenario: Owner sees own private documents and all public documents
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # alice should see her own private docs and all public docs
    Then I should see "Private Roadmap"
    And I should see "Team Guidelines"
    And I should see "Product Spec"
    # alice should not see bob's private doc
    And I should not see "Bobs Private Doc"

  Scenario: Member sees own private documents and public documents
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # charlie should see public docs
    Then I should see "Team Guidelines"
    And I should see "Product Spec"
    # charlie should not see alice's or bob's private docs
    And I should not see "Private Roadmap"
    And I should not see "Bobs Private Doc"

  Scenario: Guest sees only public documents
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should see "Team Guidelines"
    And I should see "Product Spec"
    And I should not see "Private Roadmap"
    And I should not see "Private Notes"

  Scenario: Document listing shows pinned badge
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should see "Pinned Doc"
    And I should see "Pinned"

  Scenario: Document listing links to document editor
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "Product Spec" link and wait for navigation
    Then the URL should contain "/documents/product-spec"
    And I should see "Product Spec"
    And "#editor-container" should be visible

  Scenario: Project page shows project documents
    # "Specs" is a document in the mobile-app project
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for network idle
    Then I should see "Specs"
