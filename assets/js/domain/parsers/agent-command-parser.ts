/**
 * Agent Command Parser - Pure Domain Logic
 * 
 * Parses @j agent_name Question syntax and extracts agent name and question.
 * This is pure business logic with no side effects.
 */

export interface AgentCommand {
  agentName: string;
  question: string;
}

/**
 * Parses an agent command from text in the format: @j agent_name Question
 * 
 * @param text - The text to parse
 * @returns Parsed command with agent name and question, or null if invalid
 * 
 * @example
 * parseAgentCommand("@j writer What is the format?")
 * // => { agentName: "writer", question: "What is the format?" }
 * 
 * @example
 * parseAgentCommand("regular text")
 * // => null
 */
export function parseAgentCommand(text: string): AgentCommand | null {
  // Pattern: @j followed by agent_name (alphanumeric, hyphens, underscores)
  // followed by at least one space and then the question
  const match = text.match(/^@j\s+([a-zA-Z0-9-_]+)\s+(.+)$/);
  
  if (!match) {
    return null;
  }
  
  return {
    agentName: match[1],
    question: match[2],
  };
}
