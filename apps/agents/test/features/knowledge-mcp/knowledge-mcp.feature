Feature: Knowledge MCP Tools
  As an LLM agent
  I want to search, create, update, traverse, and relate knowledge entries via MCP tools
  So that institutional knowledge is structured, queryable, and accumulates over time

  The Knowledge MCP endpoint exposes 6 tools via JSON-RPC 2.0 over HTTP:
  - knowledge.search: keyword/tag/category search
  - knowledge.get: fetch entry with relationships
  - knowledge.traverse: walk graph from entry
  - knowledge.create: create new entry
  - knowledge.update: update existing entry
  - knowledge.relate: create relationship between entries

  All operations require Bearer token authentication and are workspace-scoped.

  Background:
    Given the MCP server is running and healthy
    And I have a valid API key with workspace access

  # --- Authentication ---

  Scenario: Unauthenticated request is rejected
    When I send an MCP request without authentication
    Then I receive a 401 Unauthorized response
    And the response contains an error message about missing authorization

  Scenario: Invalid API key is rejected
    When I send an MCP request with an invalid API key
    Then I receive a 401 Unauthorized response

  Scenario: Revoked API key is rejected
    When I send an MCP request with a revoked API key
    Then I receive a 401 Unauthorized response

  # --- MCP Initialize ---

  Scenario: Successful MCP initialize handshake
    When I send an MCP initialize request with a valid API key
    Then I receive a 200 response
    And the response contains server info with name "knowledge-mcp"
    And the response contains server version "1.0.0"

  # --- knowledge.create ---

  Scenario: Create a knowledge entry with required fields
    When I call knowledge.create with title, body, and category "how_to"
    Then the entry is created successfully
    And the response contains the entry ID, title, and category

  Scenario: Create a knowledge entry with tags
    When I call knowledge.create with tags ["elixir", "phoenix"]
    Then the entry is created with the specified tags

  Scenario: Create fails without title
    When I call knowledge.create without a title
    Then I receive a validation error about title being required

  Scenario: Create fails without body
    When I call knowledge.create without a body
    Then I receive a validation error about body being required

  Scenario: Create fails with invalid category
    When I call knowledge.create with category "invalid_cat"
    Then I receive a validation error about invalid category

  # --- knowledge.get ---

  Scenario: Get a knowledge entry by ID
    Given a knowledge entry exists in the workspace
    When I call knowledge.get with the entry ID
    Then I receive the full entry with title, body, category, and tags

  Scenario: Get a non-existent entry returns not found
    When I call knowledge.get with a non-existent ID
    Then I receive an error about entry not found

  # --- knowledge.search ---

  Scenario: Search by keyword
    Given multiple knowledge entries exist in the workspace
    When I call knowledge.search with query "phoenix"
    Then I receive matching entries sorted by relevance

  Scenario: Search by category
    Given knowledge entries of different categories exist
    When I call knowledge.search with category "pattern"
    Then I receive only entries matching that category

  Scenario: Search by tags
    Given knowledge entries with various tags exist
    When I call knowledge.search with tags ["elixir"]
    Then I receive only entries with the specified tag

  Scenario: Search with no criteria fails
    When I call knowledge.search with no parameters
    Then I receive an error about empty search criteria

  Scenario: Search with no results returns empty
    When I call knowledge.search with query "nonexistent_xyz_123"
    Then I receive an empty result set

  # --- knowledge.update ---

  Scenario: Update a knowledge entry title
    Given a knowledge entry exists in the workspace
    When I call knowledge.update with a new title
    Then the entry is updated with the new title

  Scenario: Update fails for non-existent entry
    When I call knowledge.update with a non-existent ID
    Then I receive an error about entry not found

  Scenario: Update fails with invalid category
    Given a knowledge entry exists in the workspace
    When I call knowledge.update with an invalid category
    Then I receive a validation error about invalid category

  # --- knowledge.relate ---

  Scenario: Create a relationship between two entries
    Given two knowledge entries exist in the workspace
    When I call knowledge.relate with from_id, to_id, and type "relates_to"
    Then the relationship is created successfully

  Scenario: Relate fails with self-reference
    Given a knowledge entry exists in the workspace
    When I call knowledge.relate with the same entry as from_id and to_id
    Then I receive an error about self-referencing relationships

  Scenario: Relate fails with invalid relationship type
    Given two knowledge entries exist in the workspace
    When I call knowledge.relate with type "invalid_type"
    Then I receive an error about invalid relationship type

  # --- knowledge.traverse ---

  Scenario: Traverse knowledge graph from an entry
    Given knowledge entries with relationships exist
    When I call knowledge.traverse with a start entry ID
    Then I receive connected entries with relationship metadata

  Scenario: Traverse with no connections returns empty
    Given a standalone knowledge entry exists (no relationships)
    When I call knowledge.traverse with that entry ID
    Then I receive an empty traversal result

  Scenario: Traverse with invalid relationship type fails
    Given a knowledge entry exists in the workspace
    When I call knowledge.traverse with an invalid relationship type
    Then I receive an error about invalid relationship type

  # --- Health Check ---

  Scenario: Health check endpoint is accessible without auth
    When I send a GET request to /health
    Then I receive a 200 response
    And the response contains status "ok"
