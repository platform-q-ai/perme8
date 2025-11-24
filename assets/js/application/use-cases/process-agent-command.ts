/**
 * Process Agent Command - Application Layer Use Case
 * 
 * Orchestrates command parsing and validation to prepare for submission to LiveView.
 * This is the application layer that coordinates domain logic.
 */

import { parseAgentCommand } from "../../domain/parsers/agent-command-parser";
import { isValidAgentCommand } from "../../domain/validators/agent-command-validator";

/**
 * Result of processing an agent command.
 */
export interface ProcessResult {
  valid: boolean;
  agentName?: string;
  question?: string;
  error?: string;
}

/**
 * Processes an agent command text and validates it.
 * 
 * Coordinates the parsing and validation logic from the domain layer,
 * returning a result that indicates whether the command is valid and
 * provides either the parsed data or an error message.
 * 
 * @param commandText - The command text to process
 * @returns Result indicating validity with parsed data or error message
 * 
 * @example
 * processAgentCommand("@j writer How do I format this?")
 * // => { valid: true, agentName: "writer", question: "How do I format this?" }
 * 
 * @example
 * processAgentCommand("@j")
 * // => { valid: false, error: "Invalid command format" }
 */
export function processAgentCommand(commandText: string): ProcessResult {
  // Step 1: Parse the command using domain parser
  const parsed = parseAgentCommand(commandText);

  // Step 2: Validate the parsed command using domain validator
  if (!isValidAgentCommand(parsed)) {
    return {
      valid: false,
      error: "Invalid command format",
    };
  }

  // Step 3: Return valid result with parsed data
  // At this point, isValidAgentCommand guarantees parsed is not null
  return {
    valid: true,
    agentName: parsed!.agentName,
    question: parsed!.question,
  };
}
