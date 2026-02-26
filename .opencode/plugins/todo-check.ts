/**
 * Todo Check Plugin
 *
 * When a session goes idle (the agent finishes responding), this plugin
 * sends a follow-up prompt asking the agent to verify all its todos
 * have been completed.
 *
 * This prevents the agent from finishing with outstanding work items
 * still marked as pending or in_progress.
 *
 * State machine per session:
 *   "ready"   → waiting for the agent to go idle so we can prompt
 *   "pending" → we sent the todo-check prompt; ignore idle events
 *                until the agent finishes or the user sends a new message
 *
 * A user prompt (`session.prompt`) resets the state to "ready" so the
 * plugin re-arms for each user interaction. This avoids the loop that
 * occurred when interrupts (Esc) fired extra idle events while the
 * old toggle-based guard had already cleared.
 */

import type { Plugin } from "@opencode-ai/plugin"

type SessionState = "ready" | "pending"

export const TodoCheckPlugin: Plugin = async ({ client }) => {
  const sessions = new Map<string, SessionState>()

  return {
    event: async ({ event }) => {
      const sessionId = event.properties?.sessionID
      if (!sessionId) return

      // When the user sends a new prompt, re-arm so the next idle
      // will trigger a todo check.
      if (event.type === "session.prompt") {
        sessions.set(sessionId, "ready")
        return
      }

      if (event.type !== "session.idle") return

      const state = sessions.get(sessionId) ?? "ready"

      // If we already sent the todo-check and are waiting for the
      // agent to finish (or the user interrupted), stay quiet.
      if (state === "pending") return

      // Transition to pending before sending the prompt so that any
      // idle events fired by interrupts are ignored.
      sessions.set(sessionId, "pending")

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
