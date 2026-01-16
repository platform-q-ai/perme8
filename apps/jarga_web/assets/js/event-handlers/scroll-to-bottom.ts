/**
 * Scroll to Bottom Event Handler
 *
 * Handles scroll-to-bottom events dispatched from LiveView via push_event.
 * Used by chat messages container to auto-scroll when new messages arrive.
 *
 * Server-side usage:
 *   push_event(socket, "scroll_to_bottom", %{})
 *
 * @module event-handlers
 */

/**
 * Registers scroll-to-bottom event handler
 * Scrolls the chat messages container to the bottom when triggered
 */
export function registerScrollToBottomHandler(): void {
  window.addEventListener("phx:scroll_to_bottom", () => {
    const messagesContainer = document.getElementById("chat-messages");
    if (messagesContainer) {
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
  });
}
