import { describe, test, expect } from "vitest";
import { processAgentCommand } from "./process-agent-command";

describe("processAgentCommand", () => {
  describe("valid commands", () => {
    test("processes valid agent command", () => {
      const input = "@j writer How should I format this?";

      const result = processAgentCommand(input);

      expect(result).toEqual({
        valid: true,
        agentName: "writer",
        question: "How should I format this?",
      });
    });
  });

  describe("invalid commands", () => {
    test("rejects invalid command syntax", () => {
      const input = "@j";

      const result = processAgentCommand(input);

      expect(result).toEqual({
        valid: false,
        error: "Invalid command format",
      });
    });

    test("rejects command with missing agent name", () => {
      const input = "@j    Question?";

      const result = processAgentCommand(input);

      expect(result).toEqual({
        valid: false,
        error: "Invalid command format",
      });
    });

    test("rejects command with missing question", () => {
      const input = "@j agent-name";

      const result = processAgentCommand(input);

      expect(result).toEqual({
        valid: false,
        error: "Invalid command format",
      });
    });
  });
});
