Feature: MCP Tool Search
  As an LLM agent running inside an opencode session
  I want to discover what MCP tools are available on the perme8-mcp server
  So that I can understand what capabilities are accessible and how to use them

  The perme8-mcp server exposes tools via multiple tool providers (Jarga, Knowledge, etc.).
  The tool search capability lets agents list all tools, search by keyword, and group by provider.
  Results include tool name, description, and input schema for each matching tool.

  All operations require Bearer token authentication and follow the MCP protocol
  (initialize handshake, then tool calls via JSON-RPC 2.0).

  Background:
    Given the MCP server is running and healthy
    And I have a valid API key with workspace access

  # --- List All Tools ---

  Scenario: List all available tools without any filter
    When I call tools.search with no arguments
    Then I receive a list of all registered tools
    And each tool includes its name, description, and input schema

  Scenario: Tool list includes tools from all providers
    When I call tools.search with no arguments
    Then the results include tools from the Jarga provider
    And the results include tools from the Knowledge provider

  # --- Search by Keyword ---

  Scenario: Search tools by name keyword
    When I call tools.search with query "workspace"
    Then I receive tools whose names contain "workspace"
    And I do not receive tools unrelated to workspaces

  Scenario: Search tools by description keyword
    When I call tools.search with query "knowledge"
    Then I receive tools whose descriptions mention knowledge

  Scenario: Search with no matching keyword returns empty
    When I call tools.search with query "nonexistent_xyz_tool_999"
    Then I receive an empty result set

  # --- Group by Provider ---

  Scenario: Group results by provider
    When I call tools.search with group_by_provider set to true
    Then the results are grouped under provider names
    And each group contains only tools from that provider

  # --- Input Schema ---

  Scenario: Tool results include input schema details
    When I call tools.search with query "create"
    Then each matching tool includes its input schema
    And the schema lists required and optional parameters with types

  # --- Error Cases ---

  Scenario: Unauthenticated request is rejected
    When I send a tools.search request without authentication
    Then I receive a 401 Unauthorized response

  Scenario: Invalid API key is rejected
    When I send a tools.search request with an invalid API key
    Then I receive a 401 Unauthorized response
