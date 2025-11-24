import { describe, test, expect } from "vitest";
import { parseAgentCommand } from "./agent-command-parser";

describe("parseAgentCommand", () => {
  describe("valid commands", () => {
    test("parses valid @j command with single-word agent name", () => {
      const input = "@j writer What is the format?";

      const result = parseAgentCommand(input);

      expect(result).toEqual({
        agentName: "writer",
        question: "What is the format?",
      });
    });

    test("parses command with hyphenated agent name", () => {
      const input = "@j my-writer-agent Question here";

      const result = parseAgentCommand(input);

      expect(result).toEqual({
        agentName: "my-writer-agent",
        question: "Question here",
      });
    });

    test("handles questions with special characters", () => {
      const input = "@j agent What's this? (explain)";

      const result = parseAgentCommand(input);

      expect(result).toEqual({
        agentName: "agent",
        question: "What's this? (explain)",
      });
    });
  });

  describe("invalid commands", () => {
    test("returns null for invalid format (no agent name)", () => {
      const input = "@j    Question?";

      const result = parseAgentCommand(input);

      expect(result).toBeNull();
    });

    test("returns null for invalid format (no question)", () => {
      const input = "@j agent-name";

      const result = parseAgentCommand(input);

      expect(result).toBeNull();
    });

    test("returns null for non-@j text", () => {
      const input = "regular text";

      const result = parseAgentCommand(input);

      expect(result).toBeNull();
    });
  });
});
