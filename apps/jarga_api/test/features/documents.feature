Feature: Document API Access
  As a developer
  I want to create and retrieve documents via REST API using API keys
  So that I can integrate document management with external systems

  Background:
    Given the following users exist:
      | Email               | Name        |
      | alice@example.com   | Alice Smith |
      | bob@example.com     | Bob Johnson |
    And the following workspaces exist:
      | Name            | Slug            | Owner             |
      | Product Team    | product-team    | alice@example.com |
      | Engineering     | engineering     | alice@example.com |
      | Marketing       | marketing       | bob@example.com   |
    And "alice@example.com" is a member of workspace "product-team"
    And "alice@example.com" is a member of workspace "engineering"
    And "bob@example.com" is a member of workspace "marketing"

  # Document POST Endpoint - Create documents
  Scenario: User creates document via API key defaults to private visibility
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "doc-key" and body:
      """
      {
        "title": "New Product Spec",
        "content": "Detailed specifications for new product"
      }
      """
    Then the response status should be 201
    And the response should include document "New Product Spec"
    And the document "New Product Spec" should be owned by "alice@example.com"
    And the document should exist in workspace "product-team"
    And the document "New Product Spec" should have visibility "private"

  Scenario: API key without workspace access cannot create document
    Given I am logged in as "alice@example.com"
    And I have an API key "wrong-key" with access to "engineering"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "wrong-key" and body:
      """
      {
        "title": "Unauthorized Doc",
        "content": "Should not be created"
      }
      """
    Then the response status should be 403
    And the response should include error "Insufficient permissions"
    And the document "Unauthorized Doc" should not exist

  Scenario: Create document with invalid data
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "doc-key" and body:
      """
      {
        "content": "Content without title"
      }
      """
    Then the response status should be 422
    And the response should include validation error for "title"

  Scenario: Create document with explicit public visibility
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "doc-key" and body:
      """
      {
        "title": "Public Spec",
        "content": "Public specifications",
        "visibility": "public"
      }
      """
    Then the response status should be 201
    And the response should include document "Public Spec"
    And the document "Public Spec" should have visibility "public"

  Scenario: Create document with explicit private visibility
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "doc-key" and body:
      """
      {
        "title": "Private Spec",
        "content": "Private specifications",
        "visibility": "private"
      }
      """
    Then the response status should be 201
    And the response should include document "Private Spec"
    And the document "Private Spec" should have visibility "private"

  Scenario: API key with guest role cannot create document
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "guest" role in workspace "product-team"
    And I have an API key "guest-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "guest-key" and body:
      """
      {
        "title": "Should Fail",
        "content": "User doesn't have permission"
      }
      """
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: API key with owner permissions can create documents
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "owner" role in workspace "product-team"
    And I have an API key "owner-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "owner-key" and body:
      """
      {
        "title": "Owner Created Doc",
        "content": "Created by owner"
      }
      """
    Then the response status should be 201
    And the document "Owner Created Doc" should be owned by "alice@example.com"
    And the document "Owner Created Doc" should have visibility "private"

  Scenario: API key with member permissions can create documents
    Given I am logged in as "alice@example.com"
    And "alice@example.com" has "member" role in workspace "product-team"
    And I have an API key "member-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/documents" with API key "member-key" and body:
      """
      {
        "title": "Member Created Doc",
        "content": "Created by member"
      }
      """
    Then the response status should be 201
    And the response should include document "Member Created Doc"
    And the document "Member Created Doc" should be owned by "alice@example.com"
    And the document "Member Created Doc" should have visibility "private"

  # Document POST Endpoint - Create documents inside projects
  Scenario: User creates document inside a project via API key defaults to private
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a POST request to "/api/workspaces/product-team/projects/q1-launch/documents" with API key "doc-key" and body:
      """
      {
        "title": "Launch Plan",
        "content": "Detailed launch plan for Q1"
      }
      """
    Then the response status should be 201
    And the response should include document "Launch Plan"
    And the document "Launch Plan" should be owned by "alice@example.com"
    And the document should exist in workspace "product-team"
    And the document should exist in project "Q1 Launch"
    And the document "Launch Plan" should have visibility "private"

  Scenario: User creates public document inside a project
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    When I make a POST request to "/api/workspaces/product-team/projects/q1-launch/documents" with API key "doc-key" and body:
      """
      {
        "title": "Public Launch Plan",
        "content": "Public launch information",
        "visibility": "public"
      }
      """
    Then the response status should be 201
    And the response should include document "Public Launch Plan"
    And the document should exist in project "Q1 Launch"
    And the document "Public Launch Plan" should have visibility "public"

  Scenario: Cannot create document in non-existent project
    Given I am logged in as "alice@example.com"
    And I have an API key "doc-key" with access to "product-team"
    When I make a POST request to "/api/workspaces/product-team/projects/non-existent-project/documents" with API key "doc-key" and body:
      """
      {
        "title": "Orphan Doc",
        "content": "Project doesn't exist"
      }
      """
    Then the response status should be 404
    And the response should include error "Project not found"

  # Document GET Endpoint - Retrieve specific document
  Scenario: User retrieves document via API key
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And workspace "product-team" has a document "Product Spec" with slug "product-spec" and content "Detailed specifications"
    When I make a GET request to "/api/workspaces/product-team/documents/product-spec" with API key "read-key"
    Then the response status should be 200
    And the response should include document "Product Spec"
    And the response should include content "Detailed specifications"
    And the response should include owner "alice@example.com"
    And the response should include workspace slug "product-team"

  Scenario: API key cannot access document in workspace it doesn't have access to
    Given I am logged in as "alice@example.com"
    And I have an API key "eng-key" with access to "engineering"
    And workspace "product-team" has a document "Product Spec" with slug "product-spec"
    When I make a GET request to "/api/workspaces/product-team/documents/product-spec" with API key "eng-key"
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: User retrieves document they have permission to view
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And "bob@example.com" is a member of workspace "product-team"
    And workspace "product-team" has a public document "Shared Doc" with slug "shared-doc" owned by "bob@example.com"
    When I make a GET request to "/api/workspaces/product-team/documents/shared-doc" with API key "read-key"
    Then the response status should be 200
    And the response should include document "Shared Doc"
    And the response should include workspace slug "product-team"

  Scenario: User retrieves document from a project
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And workspace "product-team" has a project "Q1 Launch" with slug "q1-launch"
    And project "Q1 Launch" has a document "Launch Plan" with slug "launch-plan" and content "Detailed launch plan"
    When I make a GET request to "/api/workspaces/product-team/documents/launch-plan" with API key "read-key"
    Then the response status should be 200
    And the response should include document "Launch Plan"
    And the response should include content "Detailed launch plan"
    And the response should include workspace slug "product-team"
    And the response should include project slug "q1-launch"

  Scenario: API key respects user permissions for private documents
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And "bob@example.com" is a member of workspace "product-team"
    And "bob@example.com" has a private document "Bob's Private Doc" with slug "bobs-private-doc" in workspace "product-team"
    When I make a GET request to "/api/workspaces/product-team/documents/bobs-private-doc" with API key "read-key"
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: Document not found returns 404
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    When I make a GET request to "/api/workspaces/product-team/documents/non-existent-doc" with API key "read-key"
    Then the response status should be 404
    And the response should include error "Document not found"

  Scenario: Revoked API key cannot retrieve document
    Given I am logged in as "alice@example.com"
    And I have a revoked API key "revoked-key" with access to "product-team"
    And workspace "product-team" has a document "Product Spec" with slug "product-spec"
    When I make a GET request to "/api/workspaces/product-team/documents/product-spec" with API key "revoked-key"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  Scenario: Invalid API key cannot retrieve document
    Given workspace "product-team" has a document "Product Spec" with slug "product-spec"
    When I make a GET request to "/api/workspaces/product-team/documents/product-spec" with API key "invalid-key-12345"
    Then the response status should be 401
    And the response should include error "Invalid or revoked API key"

  # Document GET Endpoint - Verify content_hash in response
  Scenario: GET document response includes content_hash
    Given I am logged in as "alice@example.com"
    And I have an API key "read-key" with access to "product-team"
    And workspace "product-team" has a document "Hash Doc" with slug "hash-doc" and content "Test content for hashing"
    When I make a GET request to "/api/workspaces/product-team/documents/hash-doc" with API key "read-key"
    Then the response status should be 200
    And the response should include document "Hash Doc"
    And the response should include a content_hash

  # Document PATCH Endpoint - Update documents
  Scenario: Update a document title via API
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "Original Title" with slug "original-title" and content "Some content"
    When I make a PATCH request to "/api/workspaces/product-team/documents/original-title" with API key "edit-key" and body:
      """
      {
        "title": "Updated Title"
      }
      """
    Then the response status should be 200
    And the response should include document "Updated Title"
    And the response should include a content_hash

  Scenario: Update document visibility via API
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "Vis Doc" with slug "vis-doc" and content "Content"
    When I make a PATCH request to "/api/workspaces/product-team/documents/vis-doc" with API key "edit-key" and body:
      """
      {
        "visibility": "public"
      }
      """
    Then the response status should be 200
    And the document "Vis Doc" should have visibility "public"

  Scenario: Update document content via API with correct content_hash
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "Content Doc" with slug "content-doc" and content "Old content"
    When I make a GET request to "/api/workspaces/product-team/documents/content-doc" with API key "edit-key"
    Then the response status should be 200
    And I store the content_hash from the response
    When I make a PATCH request to "/api/workspaces/product-team/documents/content-doc" with API key "edit-key" using stored content_hash and body:
      """
      {
        "content": "New content via API"
      }
      """
    Then the response status should be 200
    And the response should include content "New content via API"
    And the response should include a content_hash

  Scenario: Update document title and content together via API
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "Multi Update" with slug "multi-update" and content "Original"
    When I make a GET request to "/api/workspaces/product-team/documents/multi-update" with API key "edit-key"
    Then the response status should be 200
    And I store the content_hash from the response
    When I make a PATCH request to "/api/workspaces/product-team/documents/multi-update" with API key "edit-key" using stored content_hash and body:
      """
      {
        "title": "New Multi Title",
        "content": "New multi content"
      }
      """
    Then the response status should be 200
    And the response should include document "New Multi Title"
    And the response should include content "New multi content"

  Scenario: Update document content with stale content_hash returns conflict with current state
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "Conflict Doc" with slug "conflict-doc" and content "Server content"
    When I make a PATCH request to "/api/workspaces/product-team/documents/conflict-doc" with API key "edit-key" and body:
      """
      {
        "content": "My changes",
        "content_hash": "0000000000000000000000000000000000000000000000000000000000000000"
      }
      """
    Then the response status should be 409
    And the response should include a content conflict error

  Scenario: Update document content without content_hash returns 422
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And workspace "product-team" has a document "No Hash Doc" with slug "no-hash-doc" and content "Content"
    When I make a PATCH request to "/api/workspaces/product-team/documents/no-hash-doc" with API key "edit-key" and body:
      """
      {
        "content": "New content without hash"
      }
      """
    Then the response status should be 422
    And the response should include error "content_hash is required when updating content"

  Scenario: Cannot update another user's private document via API
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    And "bob@example.com" is a member of workspace "product-team"
    And "bob@example.com" has a private document "Bob's Secret" with slug "bobs-secret" in workspace "product-team"
    When I make a PATCH request to "/api/workspaces/product-team/documents/bobs-secret" with API key "edit-key" and body:
      """
      {
        "title": "Hacked Title"
      }
      """
    Then the response status should be 403
    And the response should include error "Insufficient permissions"

  Scenario: Update non-existent document returns 404
    Given I am logged in as "alice@example.com"
    And I have an API key "edit-key" with access to "product-team"
    When I make a PATCH request to "/api/workspaces/product-team/documents/non-existent-doc" with API key "edit-key" and body:
      """
      {
        "title": "Ghost Doc"
      }
      """
    Then the response status should be 404
    And the response should include error "Document not found"
