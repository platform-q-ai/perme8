/**
 * Todo Check Plugin
 *
 * When a session goes idle (the agent finishes responding), this plugin
 * sends a follow-up prompt asking the agent to verify all its todos
 * have been completed.
 *
 * This prevents the agent from finishing with outstanding work items
 * still marked as pending or in_progress.
 */

import type { Plugin } from "@opencode-ai/plugin"

export const TodoCheckPlugin: Plugin = async ({ client }) => {
  // Track sessions we've already prompted to avoid infinite loops.
  // Once we ask "have you completed your todos?", the agent responds
  // and goes idle again -- we must not re-ask.
  const prompted = new Set<string>()

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return

      const sessionId = event.properties?.sessionID
      if (!sessionId) return

      // Skip if we already asked this session
      if (prompted.has(sessionId)) {
        prompted.delete(sessionId)
        return
      }

      // Mark that we're about to prompt this session
      prompted.add(sessionId)

      await client.session.prompt({
        path: { id: sessionId },
        body: {
          parts: [
            {
              type: "text",
              text: [
                "Before finishing, please check your todo list.",
                "Have you completed all of your todos?",
                "If any are still pending or in_progress, please complete them now.",
                "If all are done, confirm they are marked as completed.",
              ].join(" "),
            },
          ],
        },
      })
    },
  }
}
