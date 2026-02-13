@http
Feature: Document API Access
  As an API consumer
  I want to create and retrieve documents via the REST API using API keys
  So that I can integrate document management with external systems programmatically

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Document POST Endpoint - Create documents
  # ---------------------------------------------------------------------------

  Scenario: User creates document via API key defaults to private visibility
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "New Product Spec",
        "content": "Detailed specifications for new product"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "New Product Spec"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.visibility" should equal "private"
    And I store response body path "$.data.slug" as "createdDocSlug"

  Scenario: API key without workspace access cannot create document
    # Assumes: alice@example.com has API key with access to engineering (NOT product-team)
    Given I set bearer token to "${valid-key-engineering-only}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Unauthorized Doc",
        "content": "Should not be created"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Create document with invalid data
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "content": "Content without title"
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.title" should exist

  Scenario: Create document with explicit public visibility
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Public Spec",
        "content": "Public specifications",
        "visibility": "public"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Public Spec"
    And the response body path "$.data.visibility" should equal "public"

  Scenario: Create document with explicit private visibility
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Private Spec",
        "content": "Private specifications",
        "visibility": "private"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Private Spec"
    And the response body path "$.data.visibility" should equal "private"

  Scenario: Owner role API key can create documents
    # Assumes: alice@example.com has "owner" role in product-team (workspace creator)
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Owner Created Doc",
        "content": "Created by owner"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Owner Created Doc"
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.visibility" should equal "private"

  Scenario: Member role API key can create documents
    # Assumes: bob@example.com has "member" role in product-team
    # Assumes: API key "${valid-member-key-product-team}" is owned by bob@example.com
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Member Created Doc",
        "content": "Created by member"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Member Created Doc"
    And the response body path "$.data.owner" should equal "bob@example.com"
    And the response body path "$.data.visibility" should equal "private"

  Scenario: Guest role API key cannot create document
    # Assumes: guest@example.com has "guest" role in product-team
    # Assumes: API key "${valid-guest-key-product-team}" is owned by guest@example.com
    Given I set bearer token to "${valid-guest-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Should Fail",
        "content": "Guest cannot create documents"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  # ---------------------------------------------------------------------------
  # Document POST Endpoint - Create documents inside projects
  # ---------------------------------------------------------------------------

  Scenario: User creates document inside a project via API key defaults to private
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects/q1-launch/documents" with body:
      """
      {
        "title": "API Launch Plan",
        "content": "Detailed launch plan for Q1"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "API Launch Plan"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.project_slug" should equal "q1-launch"
    And the response body path "$.data.visibility" should equal "private"
    And I store response body path "$.data.slug" as "projectDocSlug"

  Scenario: User creates public document inside a project
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects/q1-launch/documents" with body:
      """
      {
        "title": "Public Launch Plan",
        "content": "Public launch information",
        "visibility": "public"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Public Launch Plan"
    And the response body path "$.data.project_slug" should equal "q1-launch"
    And the response body path "$.data.visibility" should equal "public"

  Scenario: Cannot create document in non-existent project
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/projects/non-existent-project/documents" with body:
      """
      {
        "title": "Orphan Doc",
        "content": "Project doesn't exist"
      }
      """
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Project not found"

  # ---------------------------------------------------------------------------
  # Document GET Endpoint - Retrieve specific document
  # ---------------------------------------------------------------------------

  Scenario: User retrieves document via API key
    # Assumes: workspace product-team has document "Product Spec" with slug "product-spec"
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/product-spec"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Product Spec"
    And the response body path "$.data.content" should equal "Detailed specifications"
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.slug" should equal "product-spec"

  Scenario: API key cannot access document in workspace it doesn't have access to
    # Assumes: API key has access to engineering, NOT product-team
    # Assumes: workspace product-team has document "Product Spec" with slug "product-spec"
    Given I set bearer token to "${valid-key-engineering-only}"
    When I GET "/api/workspaces/product-team/documents/product-spec"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: User retrieves document they have permission to view
    # Assumes: bob@example.com is a member of product-team and owns "Shared Doc"
    # Assumes: alice@example.com has API key with access to product-team
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/shared-doc"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Shared Doc"
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: User retrieves document from a project
    # Assumes: workspace product-team has project "Q1 Launch" (slug: q1-launch)
    # Assumes: project has document "Launch Plan" with slug "launch-plan"
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/launch-plan"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Launch Plan"
    And the response body path "$.data.content" should equal "Detailed launch plan"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.project_slug" should equal "q1-launch"

  Scenario: API key respects user permissions for private documents
    # Assumes: bob@example.com has a private document in product-team
    # Assumes: alice@example.com has API key -- should NOT see Bob's private doc
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/bobs-private-doc"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Document not found returns 404
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/non-existent-doc"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Document not found"

  Scenario: Revoked API key cannot retrieve document
    # Assumes: API key was valid but has been revoked
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/product-spec"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot retrieve document
    Given I set bearer token to "invalid-key-12345"
    When I GET "/api/workspaces/product-team/documents/product-spec"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  # ---------------------------------------------------------------------------
  # Document GET Endpoint - Verify content_hash in response
  # ---------------------------------------------------------------------------

  Scenario: GET document response includes content_hash
    # Create a document first, then GET it and verify content_hash is present
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Hash Doc",
        "content": "Test content for hashing"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "hashDocSlug"
    # Now GET the document and verify content_hash
    Given I set bearer token to "${valid-read-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/${hashDocSlug}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Hash Doc"
    And the response body path "$.data.content_hash" should exist
    And the response body path "$.data.content_hash" should match "^[a-f0-9]{64}$"

  # ---------------------------------------------------------------------------
  # Document PATCH Endpoint - Update documents
  # ---------------------------------------------------------------------------

  Scenario: Update a document title via API
    # Create a document first, then PATCH its title
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Original Title",
        "content": "Some content"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "originalTitleSlug"
    # PATCH the title
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${originalTitleSlug}" with body:
      """
      {
        "title": "Updated Title"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Updated Title"
    And the response body path "$.data.content_hash" should exist
    And the response body path "$.data.content_hash" should match "^[a-f0-9]{64}$"

  Scenario: Update document visibility via API
    # Create a private document first, then PATCH visibility to public
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Vis Doc",
        "content": "Content",
        "visibility": "private"
      }
      """
    Then the response status should be 201
    And the response body path "$.data.visibility" should equal "private"
    And I store response body path "$.data.slug" as "visDocSlug"
    # PATCH visibility to public
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${visDocSlug}" with body:
      """
      {
        "visibility": "public"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Vis Doc"
    And the response body path "$.data.visibility" should equal "public"

  Scenario: Update document content via API with correct content_hash
    # Create a document, GET its content_hash, then PATCH content with the hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Content Doc",
        "content": "Old content"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "contentDocSlug"
    # GET the document to retrieve the current content_hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/${contentDocSlug}"
    Then the response status should be 200
    And the response body path "$.data.content_hash" should exist
    And I store response body path "$.data.content_hash" as "contentDocHash"
    # PATCH the content with the correct content_hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${contentDocSlug}" with body:
      """
      {
        "content": "New content via API",
        "content_hash": "${contentDocHash}"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.content" should equal "New content via API"
    And the response body path "$.data.content_hash" should exist
    And the response body path "$.data.content_hash" should match "^[a-f0-9]{64}$"

  Scenario: Update document title and content together via API
    # Create a document, GET its content_hash, then PATCH both title and content
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Multi Update",
        "content": "Original"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "multiUpdateSlug"
    # GET the document to retrieve the current content_hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I GET "/api/workspaces/product-team/documents/${multiUpdateSlug}"
    Then the response status should be 200
    And I store response body path "$.data.content_hash" as "multiUpdateHash"
    # PATCH title and content together
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${multiUpdateSlug}" with body:
      """
      {
        "title": "New Multi Title",
        "content": "New multi content",
        "content_hash": "${multiUpdateHash}"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "New Multi Title"
    And the response body path "$.data.content" should equal "New multi content"
    And the response body path "$.data.content_hash" should exist

  Scenario: Update document content with stale content_hash returns conflict with current state
    # Create a document, then PATCH content with a deliberately wrong hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "Conflict Doc",
        "content": "Server content"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "conflictDocSlug"
    # PATCH with a stale/wrong content_hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${conflictDocSlug}" with body:
      """
      {
        "content": "My changes",
        "content_hash": "0000000000000000000000000000000000000000000000000000000000000000"
      }
      """
    Then the response status should be 409
    And the response body should be valid JSON
    And the response body path "$.error" should equal "content_conflict"
    And the response body path "$.data.content" should equal "Server content"
    And the response body path "$.data.content_hash" should exist
    And the response body path "$.data.content_hash" should match "^[a-f0-9]{64}$"

  Scenario: Update document content without content_hash returns 422
    # Create a document, then try to PATCH content without providing content_hash
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I POST to "/api/workspaces/product-team/documents" with body:
      """
      {
        "title": "No Hash Doc",
        "content": "Content"
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.slug" as "noHashDocSlug"
    # PATCH content without content_hash -- should fail
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/${noHashDocSlug}" with body:
      """
      {
        "content": "New content without hash"
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.error" should equal "content_hash is required when updating content"

  Scenario: Cannot update another user's private document via API
    # Bob's private doc "bobs-private-doc" exists in seed data
    # Alice's owner-level key should NOT be able to update Bob's private document
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/bobs-private-doc" with body:
      """
      {
        "title": "Hacked Title"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Update non-existent document returns 404
    Given I set bearer token to "${valid-doc-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/documents/non-existent-doc" with body:
      """
      {
        "title": "Ghost Doc"
      }
      """
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Document not found"