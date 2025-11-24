/**
 * Agent Command Validator - Pure Domain Logic
 * 
 * Validates that an agent command has all required fields and they are not empty.
 */

import type { AgentCommand } from "../parsers/agent-command-parser";

/**
 * Validates an agent command to ensure it has all required fields.
 * 
 * @param command - The command to validate (can be null if parsing failed)
 * @returns True if the command is valid, false otherwise
 * 
 * @example
 * isValidAgentCommand({ agentName: "writer", question: "Help?" })
 * // => true
 * 
 * @example
 * isValidAgentCommand({ agentName: "", question: "Help?" })
 * // => false
 * 
 * @example
 * isValidAgentCommand(null)
 * // => false
 */
export function isValidAgentCommand(command: AgentCommand | null): boolean {
  if (!command) {
    return false;
  }

  if (!command.agentName || command.agentName.trim() === "") {
    return false;
  }

  if (!command.question || command.question.trim() === "") {
    return false;
  }

  return true;
}
