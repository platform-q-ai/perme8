@browser
Feature: Document CRUD Operations
  As a workspace member
  I want to create, update, and delete documents
  So that I can manage my team's documentation

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #   eve@example.com     - not a member of workspace "product-team"

  # Document Creation

  Scenario: Owner creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "[name='title']" with "Product Roadmap"
    And I click the "Create Document" button
    And I wait for the page to load
    Then the URL should contain "/documents/product-roadmap"
    And I should see "Product Roadmap"

  Scenario: Admin creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "[name='title']" with "Architecture Doc"
    And I click the "Create Document" button
    And I wait for the page to load
    Then the URL should contain "/documents/"
    And I should see "Architecture Doc"

  Scenario: Member creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "[name='title']" with "Meeting Notes"
    And I click the "Create Document" button
    And I wait for the page to load
    Then the URL should contain "/documents/"
    And I should see "Meeting Notes"

  Scenario: Guest cannot create documents
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    Then I should not see "New Document"

  Scenario: Document slug handles special characters
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "[name='title']" with "Product & Services (2024)"
    And I click the "Create Document" button
    And I wait for the page to load
    Then the URL should contain "/documents/"
    And I should see "Product & Services (2024)"

  # Document Updates

  Scenario: Owner updates their own document title
    # Precondition: alice owns a document "Draft Roadmap" in product-team (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/draft-roadmap"
    And I wait for the page to load
    And I click "h1"
    And I wait for "#document-title-input" to be visible
    And I clear "#document-title-input"
    And I fill "#document-title-input" with "Product Roadmap Q1"
    And I press "Enter"
    And I wait for network idle
    Then I should see "Product Roadmap Q1"

  Scenario: Owner changes document visibility to public
    # Precondition: alice owns a private document (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/private-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Make Public" button
    And I wait for network idle
    Then I should see "Document is now shared with workspace members"

  Scenario: Owner changes document visibility to private
    # Precondition: alice owns a public document (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/public-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Make Private" button
    And I wait for network idle
    Then I should see "Document is now private"

  Scenario: Guest cannot edit any documents
    # Precondition: a public document exists (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/public-doc"
    And I wait for the page to load
    Then I should see "read-only mode"
    And ".kebab-menu" should not exist

  Scenario: Update document with empty title
    # Precondition: alice owns a document "Valid Title" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/valid-title"
    And I wait for the page to load
    And I click "h1"
    And I wait for "#document-title-input" to be visible
    And I clear "#document-title-input"
    And I fill "#document-title-input" with ""
    And I press "Enter"
    And I wait for network idle
    Then I should see "Valid Title"

  # Document Pinning

  Scenario: Owner pins their own document
    # Precondition: alice owns an unpinned document (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/important-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Pin Document" button
    And I wait for network idle
    Then I should see "Document pinned"

  Scenario: Owner unpins their own document
    # Precondition: alice owns a pinned document (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/pinned-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Unpin Document" button
    And I wait for network idle
    Then I should see "Document unpinned"

  Scenario: Guest cannot pin any documents
    # Precondition: a public document exists (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/public-doc"
    And I wait for the page to load
    Then ".kebab-menu" should not exist

  # Document Deletion

  Scenario: Owner deletes their own document
    # Precondition: alice owns a document "Old Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/old-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Delete Document" button
    And I wait for the page to load
    Then the URL should contain "/app/workspaces/product-team"
    And I should see "Document deleted"
    And I should not see "Old Doc"

  Scenario: Guest cannot delete any documents
    # Precondition: a public document exists (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/public-doc"
    And I wait for the page to load
    Then ".kebab-menu" should not exist
    And I should not see "Delete Document"
