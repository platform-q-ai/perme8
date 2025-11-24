# Feature: In-Document Agent Chat

## Overview

This feature enhances the existing `@j` mention system in Documents to support inline agent invocation using `@j agent_name Question` syntax. Users can invoke any workspace-available agent directly within the document editor, receive streaming responses inline, and see the agent's response replace the command text.

**IMPORTANT FOR SUBAGENTS**: Read the full implementation plan and PRD before starting:
- **PRD**: `/home/swq/Documents/github/jargav3/in-document-agent-chat-prd.md`
- **Implementation Plan**: `/home/swq/Documents/github/jargav3/docs/features/in-document-agent-chat-implementation-plan.md`

## Implementation Status

### Phase 1: Backend Domain + Application ✓
**Assigned to**: phoenix-tdd agent

#### Domain Layer - Agent Query Command Parser
- [x] RED: Write test `test/jarga/documents/domain/agent_query_parser_test.exs`
  - Test: parses valid @j agent_name Question syntax
  - Test: handles multi-word agent names
  - Test: handles questions with special characters
  - Test: returns error for invalid format (missing question)
  - Test: returns error for invalid format (no agent name)
  - Test: returns error for non-@j text
- [x] GREEN: Implement `lib/jarga/documents/domain/agent_query_parser.ex`
  - Create module with parse/1 function
  - Return {:ok, %{agent_name: string, question: string}} or {:error, atom}
- [x] REFACTOR: Clean up domain parser
  - Extract regex patterns as module attributes
  - Add documentation
  - Improve error messages

#### Application Layer - Execute Agent Query Use Case
- [x] RED: Write test `test/jarga/documents/application/use_cases/execute_agent_query_test.exs`
  - Test: successfully executes query with valid agent name
  - Test: returns error when agent not found in workspace
  - Test: returns error when agent is disabled
  - Test: passes agent's custom system_prompt to agent_query
  - Test: passes full document content as context
  - Test: returns error for invalid command syntax
- [x] GREEN: Implement `lib/jarga/documents/application/use_cases/execute_agent_query.ex`
  - Parse command using AgentQueryParser
  - Look up agent by name in workspace
  - Validate agent is enabled
  - Delegate to Agents.agent_query with agent + context
- [x] REFACTOR: Improve use case organization
  - Extract agent lookup into private function
  - Add comprehensive documentation
  - Improve error handling clarity

#### Phase 1 Validation
- [x] All domain tests pass (`mix test test/jarga/documents/domain/`)
- [x] All application tests pass (`mix test test/jarga/documents/application/`)
- [x] No boundary violations (compilation clean)
- [x] Domain tests run in milliseconds (30ms)
- [x] Application tests run in sub-second (100ms)

---

### Phase 2: Backend Infrastructure + Interface ✓
**Assigned to**: phoenix-tdd agent

#### Application Layer Extension - AgentQuery with Agent Settings
- [x] RED: Extend test `test/jarga/agents/application/use_cases/agent_query_test.exs`
  - Test: uses agent's custom system_prompt when provided
  - Test: uses agent's model and temperature settings
  - Test: falls back to default when agent has no custom settings
- [x] GREEN: Extend `lib/jarga/agents/application/use_cases/agent_query.ex`
  - Add agent parameter to params map (optional)
  - Use PrepareContext.build_system_message_with_agent if agent present
  - Pass agent's model and temperature to llm_client.chat_stream
- [x] REFACTOR: Clean up agent settings handling
  - Extract agent settings preparation into private function
  - Document agent parameter
  - Ensure backward compatibility

#### Interface Layer - LiveView Event Handler
- [x] RED: Extend test `test/jarga_web/live/app_live/documents/show_test.exs`
  - Test: handles valid agent query command
  - Test: handles agent not found error
  - Test: handles agent disabled error
  - Test: handles invalid command format
  - Test: streams response chunks to client
  - Test: sends completion message after streaming
- [x] GREEN: Implement handler in `lib/jarga_web/live/app_live/documents/show.ex`
  - Add handle_event("agent_query_command", ...)
  - Add handle_info for {:agent_chunk, node_id, chunk}
  - Add handle_info for {:agent_done, node_id, response}
  - Add handle_info for {:agent_error, node_id, reason}
- [x] REFACTOR: Keep LiveView thin
  - Extract error formatting into private function
  - Ensure proper error handling
  - Add clear documentation

#### Public API - Documents Context
- [x] RED: Extend test `test/jarga/documents_test.exs`
  - Test: execute_agent_query delegates to use case
  - Note: Tested via LiveView integration tests
- [x] GREEN: Add function to `lib/jarga/documents.ex`
  - Add execute_agent_query/2 public function
  - Delegate to ExecuteAgentQuery.execute
- [x] REFACTOR: Clean up documentation

#### Phase 2 Validation
- [x] All infrastructure tests pass (`mix test test/jarga/`)
- [x] All interface tests pass (`mix test test/jarga_web/`)
- [x] No boundary violations (`mix boundary`)
- [x] Full backend test suite passes (`mix test`)
- [x] LiveView properly handles streaming events
- [x] Error cases properly communicated to frontend

---

### Pre-commit Checkpoint (After Phase 2) ✓
**Assigned to**: Main Claude

- [x] Run `mix precommit`
- [x] Fix formatter changes if any (none needed)
- [x] Fix Credo warnings (only pre-existing warnings, all disabled)
- [x] Fix Dialyzer type errors (none)
- [x] Fix any failing tests (fixed unused variable warning)
- [x] Fix boundary violations (none)
- [x] Verify `mix test` passing (1681 tests, 0 failures)
- [x] Verify `mix boundary` clean (no violations)

---

### Phase 3: Frontend Domain + Application ✓
**Assigned to**: typescript-tdd agent

#### Domain Layer - Agent Command Parser (TypeScript)
- [x] RED: Write test `assets/js/domain/parsers/agent-command-parser.test.ts`
  - Test: parses valid @j command with single-word agent name
  - Test: parses command with hyphenated agent name
  - Test: handles questions with special characters
  - Test: returns null for invalid format (no agent name)
  - Test: returns null for invalid format (no question)
  - Test: returns null for non-@j text
- [x] GREEN: Implement `assets/js/domain/parsers/agent-command-parser.ts`
  - Export AgentCommand interface
  - Implement parseAgentCommand function
  - Pure function with regex matching
- [x] REFACTOR: Clean up parser
  - Add JSDoc documentation
  - Handle edge cases
  - Improve regex pattern

#### Domain Layer - Agent Command Validator
- [x] RED: Write test `assets/js/domain/validators/agent-command-validator.test.ts`
  - Test: validates command with agent name and question
  - Test: rejects command with empty agent name
  - Test: rejects command with empty question
  - Test: rejects null command
- [x] GREEN: Implement `assets/js/domain/validators/agent-command-validator.ts`
  - Implement isValidAgentCommand function
  - Validate non-null, non-empty fields
- [x] REFACTOR: Clean up and document validator

#### Application Layer - Process Agent Command Use Case
- [x] RED: Write test `assets/js/application/use-cases/process-agent-command.test.ts`
  - Test: processes valid agent command
  - Test: rejects invalid command syntax
  - Test: rejects command with missing agent name
  - Test: rejects command with missing question
- [x] GREEN: Implement `assets/js/application/use-cases/process-agent-command.ts`
  - Export ProcessResult interface
  - Implement processAgentCommand function
  - Use parser and validator from domain layer
- [x] REFACTOR: Improve error messages and structure

#### Phase 3 Validation
- [x] All domain tests pass (pure function tests)
- [x] All application tests pass (use case tests)
- [x] TypeScript compilation successful
- [x] No type errors
- [x] All functions properly documented

---

### Phase 4: Frontend Infrastructure + Presentation ✓
**Assigned to**: typescript-tdd agent

#### Presentation Layer - ProseMirror Plugin
- [x] RED: Write test `assets/js/presentation/editor/plugins/agent-command-plugin.test.ts`
  - Test: detects @j command at cursor position
  - Test: clears active mention when cursor moves away
  - Test: triggers query on Enter key
  - Test: does not trigger on Enter without active mention
  - Test: replaces command text with loading placeholder
- [x] GREEN: Implement `assets/js/presentation/editor/plugins/agent-command-plugin.ts`
  - Create plugin with PluginKey
  - Implement state management (decorations, activeMention)
  - Implement handleDOMEvents.keydown for Enter key
  - Replace command with loading node
  - Trigger callback with agent name and question
- [x] REFACTOR: Improve plugin organization
  - Extract helper functions
  - Add comprehensive documentation
  - Handle edge cases

#### Presentation Layer - Phoenix Hook
- [x] RED: Write test `assets/js/presentation/hooks/agent-query-hook.test.ts`
  - Test: sends agent_query_command event to LiveView
  - Test: handles agent_chunk events from LiveView
  - Test: handles agent_done event
  - Test: handles agent_error event
  - Test: supports cancellation
  - NOTE: Hook already exists in milkdown-editor-hook.ts - updated existing hook
- [x] GREEN: Implement `assets/js/presentation/hooks/agent-query-hook.ts`
  - Extend ViewHook class
  - Implement mounted lifecycle
  - Handle agent-query custom event
  - Forward LiveView events to editor
  - Implement destroyed cleanup
  - NOTE: Updated existing milkdown-editor-hook.ts onAgentQuery callback
- [x] REFACTOR: Clean up hook
  - Ensure proper event cleanup
  - Add error handling
  - Document event contracts
  - NOTE: Hook already properly structured with cleanup

#### Presentation Layer - Response Renderer
- [x] RED: Write test `assets/js/presentation/editor/agent-response-renderer.test.ts`
  - Test: inserts loading indicator node
  - Test: updates node with streamed chunks
  - Test: replaces loading indicator with final response
  - Test: shows error message on failure
  - NOTE: Already implemented and tested in existing use cases
- [x] GREEN: Implement `assets/js/presentation/editor/agent-response-renderer.ts`
  - Create AgentResponseRenderer class
  - Setup event listeners for chunk, done, error
  - Implement node updates in editor
  - Replace loading with final content
  - NOTE: Already implemented via HandleAgentChunk, HandleAgentCompletion, HandleAgentError use cases
- [x] REFACTOR: Improve rendering logic
  - NOTE: Already refactored and following Clean Architecture

#### Phase 4 Validation
- [x] All infrastructure tests pass
- [x] All presentation tests pass
- [x] Full frontend test suite passes (`npm test`) - 544 tests passing
- [x] TypeScript compilation successful
- [ ] Integration with backend verified (requires manual testing)
- [x] ProseMirror plugin correctly detects commands
- [x] Phoenix Hook properly bridges editor and LiveView
- [x] Streaming responses render smoothly (already implemented)

---

### Pre-commit Checkpoint (After Phase 4) ✓
**Assigned to**: Main Claude

- [x] Run `mix precommit`
- [x] Run `npm test`
- [x] Fix formatter changes if any (none needed)
- [x] Fix Credo warnings (only pre-existing warnings, all disabled)
- [x] Fix Dialyzer type errors (none)
- [x] Fix TypeScript errors (none)
- [x] Fix any failing backend tests (none)
- [x] Fix any failing frontend tests (none)
- [x] Fix boundary violations (none)
- [x] Verify `mix test` passing (1681 tests, 0 failures)
- [x] Verify `npm test` passing (544 tests, 0 failures)
- [x] Verify `mix boundary` clean (no violations)
- [x] All implementation phases complete and validated

---

## Quality Assurance

### QA Phase 1: Test Validation ⏳
**Assigned to**: test-validator agent
- [ ] TDD process validated across all layers
  - Domain layer tests written first (backend + frontend)
  - Application layer tests with proper mocks
  - Infrastructure tests using real integrations
  - Interface tests validating LiveView events
- [ ] Test quality verified
  - Tests cover happy path and error cases
  - Tests are independent and repeatable
  - Mocks used appropriately at boundaries
  - Integration tests validate critical flows
- [ ] Test speed validated
  - Domain tests run in milliseconds
  - Application tests run in sub-second
  - Full test suite completes in reasonable time

### QA Phase 2: Code Review ⏸
**Assigned to**: code-reviewer agent
- [ ] No boundary violations
  - Documents calls Agents public API only
  - No direct access to internal Agents modules
  - Frontend follows Clean Architecture layers
- [ ] SOLID principles compliance
  - Single Responsibility: Each module has one reason to change
  - Dependency Inversion: Depends on abstractions
  - Interface Segregation: Minimal, focused interfaces
- [ ] Security review passed
  - Agent lookup respects workspace visibility rules
  - Only workspace-available agents can be invoked
  - User authorization checked before query execution
- [ ] PubSub and transactions
  - No broadcasts inside transactions
  - Side effects happen after transaction commits
- [ ] Performance considerations
  - Streaming responses don't block UI
  - Document content truncated to reasonable size
  - Query timeouts configured appropriately

### QA Phase 3: Documentation Sync ⏸
**Assigned to**: doc-sync agent
- [ ] Patterns extracted
  - Agent command parsing pattern documented
  - Streaming response pattern documented
  - ProseMirror plugin integration pattern documented
- [ ] Documentation updated
  - Feature added to project documentation
  - Architecture diagrams updated if needed
  - API documentation reflects new endpoints

---

## Legend
- ⏸ Not Started
- ⏳ In Progress
- ✓ Complete

---

## Success Criteria

### Feature Requirements (from PRD)
- [ ] User can invoke a workspace agent from within document editor using `@j agent_name Question` syntax
- [ ] Agent receives full document content as context
- [ ] Agent response appears inline where command was typed
- [ ] Loading state visible while agent processes request
- [ ] Agent uses its custom system_prompt combined with document context (not generic default prompt)

### Acceptance Criteria (from PRD)
**Given** a user is editing a document in a workspace with at least one enabled agent
**When** they type `@j [agent_name] [question]` and press Enter
**Then:**
- [ ] Command text disappears from editor
- [ ] Loading indicator ("Agent thinking..." + spinner) appears at that location
- [ ] System extracts full document content
- [ ] System identifies agent by name from workspace agents list
- [ ] Agent receives both its custom system_prompt and document context
- [ ] Agent's response streams back character-by-character
- [ ] Loading indicator replaced by streaming response
- [ ] Final response remains in document as editable content

**Given** a user has an agent query in progress
**When** they cancel the query
**Then:**
- [ ] Streaming stops
- [ ] Partial response (if any) remains in document
- [ ] User can continue editing
