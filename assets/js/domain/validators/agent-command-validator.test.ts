import { describe, test, expect } from "vitest";
import { isValidAgentCommand } from "./agent-command-validator";
import type { AgentCommand } from "../parsers/agent-command-parser";

describe("isValidAgentCommand", () => {
  describe("valid commands", () => {
    test("validates command with agent name and question", () => {
      const command: AgentCommand = {
        agentName: "writer",
        question: "What is this?",
      };

      const result = isValidAgentCommand(command);

      expect(result).toBe(true);
    });
  });

  describe("invalid commands", () => {
    test("rejects command with empty agent name", () => {
      const command: AgentCommand = {
        agentName: "",
        question: "Question",
      };

      const result = isValidAgentCommand(command);

      expect(result).toBe(false);
    });

    test("rejects command with empty question", () => {
      const command: AgentCommand = {
        agentName: "agent",
        question: "",
      };

      const result = isValidAgentCommand(command);

      expect(result).toBe(false);
    });

    test("rejects null command", () => {
      const result = isValidAgentCommand(null);

      expect(result).toBe(false);
    });
  });
});
