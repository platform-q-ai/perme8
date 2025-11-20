/**
 * Focus Editor Event Handler
 *
 * Handles focus-editor events dispatched from LiveView.
 * Used by document title input to focus the editor after pressing Enter.
 *
 * Server-side usage:
 *   push_event(socket, "focus-editor", %{})
 *
 * @module event-handlers
 */

/**
 * Registers focus-editor event handler
 * Focuses the ProseMirror editor after a short delay to allow blur event to process
 */
export function registerFocusEditorHandler(): void {
  window.addEventListener("phx:focus-editor", () => {
    setTimeout(() => {
      const editor = document.querySelector('#editor-container .ProseMirror') as HTMLElement;
      if (editor) {
        editor.focus();
      }
    }, 100);
  });
}
