@http
Feature: Document API Access
  As an API consumer
  I want to create and retrieve documents via the REST API using API keys
  So that I can integrate document management with external systems programmatically

  Background:
    Given I set variable "baseUrl" to "http://localhost:4000/api"
    And I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Document POST Endpoint - Create documents
  # ---------------------------------------------------------------------------

  Scenario: User creates document via API key defaults to private visibility
    # Assumes: alice@example.com has API key "${docKey}" with access to product-team
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
      """
      {
        "title": "New Product Spec",
        "content": "Detailed specifications for new product"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "New Product Spec"
    And the response body path "$.data.content" should equal "Detailed specifications for new product"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.visibility" should equal "private"
    And I store response body path "$.data.slug" as "createdDocSlug"

  Scenario: API key without workspace access cannot create document
    # Assumes: alice@example.com has API key "${wrongKey}" with access to engineering (NOT product-team)
    Given I set variable "wrongKey" to "valid-key-engineering-only"
    And I set bearer token to "${wrongKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
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
    # Assumes: alice@example.com has API key "${docKey}" with access to product-team
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
      """
      {
        "content": "Content without title"
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.title" should exist

  Scenario: Create document with explicit public visibility
    # Assumes: alice@example.com has API key "${docKey}" with access to product-team
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
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
    # Assumes: alice@example.com has API key "${docKey}" with access to product-team
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
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

  Scenario: API key with viewer role cannot create document
    # Assumes: alice@example.com has "viewer" role in product-team
    # Assumes: API key "${viewerKey}" is tied to alice@example.com with access to product-team
    Given I set variable "viewerKey" to "valid-viewer-key-product-team"
    And I set bearer token to "${viewerKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
      """
      {
        "title": "Should Fail",
        "content": "User doesn't have permission"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: API key with owner permissions can create documents
    # Assumes: alice@example.com has "owner" role in product-team
    # Assumes: API key "${ownerKey}" is tied to alice@example.com with access to product-team
    Given I set variable "ownerKey" to "valid-owner-key-product-team"
    And I set bearer token to "${ownerKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
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

  Scenario: API key with editor permissions can create documents
    # Assumes: alice@example.com has "editor" role in product-team
    # Assumes: API key "${editorKey}" is tied to alice@example.com with access to product-team
    Given I set variable "editorKey" to "valid-editor-key-product-team"
    And I set bearer token to "${editorKey}"
    When I POST to "${baseUrl}/workspaces/product-team/documents" with body:
      """
      {
        "title": "Editor Created Doc",
        "content": "Created by editor"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Editor Created Doc"
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.visibility" should equal "private"

  # ---------------------------------------------------------------------------
  # Document POST Endpoint - Create documents inside projects
  # ---------------------------------------------------------------------------

  Scenario: User creates document inside a project via API key defaults to private
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/projects/q1-launch/documents" with body:
      """
      {
        "title": "Launch Plan",
        "content": "Detailed launch plan for Q1"
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Launch Plan"
    And the response body path "$.data.slug" should exist
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.project_slug" should equal "q1-launch"
    And the response body path "$.data.visibility" should equal "private"
    And I store response body path "$.data.slug" as "projectDocSlug"

  Scenario: User creates public document inside a project
    # Assumes: workspace product-team has project "Q1 Launch" with slug "q1-launch"
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/projects/q1-launch/documents" with body:
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
    Given I set variable "docKey" to "valid-doc-key-product-team"
    And I set bearer token to "${docKey}"
    When I POST to "${baseUrl}/workspaces/product-team/projects/non-existent-project/documents" with body:
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
    Given I set variable "readKey" to "valid-read-key-product-team"
    And I set bearer token to "${readKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/product-spec"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Product Spec"
    And the response body path "$.data.content" should equal "Detailed specifications"
    And the response body path "$.data.owner" should equal "alice@example.com"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.slug" should equal "product-spec"

  Scenario: API key cannot access document in workspace it doesn't have access to
    # Assumes: API key "${engKey}" has access to engineering, NOT product-team
    # Assumes: workspace product-team has document "Product Spec" with slug "product-spec"
    Given I set variable "engKey" to "valid-key-engineering-only"
    And I set bearer token to "${engKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/product-spec"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: User retrieves document they have permission to view
    # Assumes: bob@example.com is a member of product-team and owns "Shared Doc"
    # Assumes: alice@example.com has API key "${readKey}" with access to product-team
    Given I set variable "readKey" to "valid-read-key-product-team"
    And I set bearer token to "${readKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/shared-doc"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Shared Doc"
    And the response body path "$.data.workspace_slug" should equal "product-team"

  Scenario: User retrieves document from a project
    # Assumes: workspace product-team has project "Q1 Launch" (slug: q1-launch)
    # Assumes: project has document "Launch Plan" with slug "launch-plan"
    Given I set variable "readKey" to "valid-read-key-product-team"
    And I set bearer token to "${readKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/launch-plan"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.title" should equal "Launch Plan"
    And the response body path "$.data.content" should equal "Detailed launch plan"
    And the response body path "$.data.workspace_slug" should equal "product-team"
    And the response body path "$.data.project_slug" should equal "q1-launch"

  Scenario: API key respects user permissions for private documents
    # Assumes: bob@example.com has a private document in product-team
    # Assumes: alice@example.com has API key "${readKey}" -- should NOT see Bob's private doc
    Given I set variable "readKey" to "valid-read-key-product-team"
    And I set bearer token to "${readKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/bobs-private-doc"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Document not found returns 404
    Given I set variable "readKey" to "valid-read-key-product-team"
    And I set bearer token to "${readKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/non-existent-doc"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Document not found"

  Scenario: Revoked API key cannot retrieve document
    # Assumes: API key "${revokedKey}" was valid but has been revoked
    Given I set variable "revokedKey" to "revoked-key-product-team"
    And I set bearer token to "${revokedKey}"
    When I GET "${baseUrl}/workspaces/product-team/documents/product-spec"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Invalid API key cannot retrieve document
    Given I set bearer token to "invalid-key-12345"
    When I GET "${baseUrl}/workspaces/product-team/documents/product-spec"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"
