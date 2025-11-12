/**
 * EditorAdapter Interface
 *
 * Defines the contract for editor operations (ProseMirror/Milkdown).
 * This interface enables dependency inversion - use cases depend on this abstraction,
 * not on concrete editor implementations.
 *
 * Implementations will be provided by the infrastructure layer (Phase 3).
 *
 * @example
 * ```typescript
 * // Infrastructure layer provides concrete implementation
 * class ProseMirrorEditorAdapter implements EditorAdapter {
 *   constructor(private view: EditorView) {}
 *
 *   insertNode(node: any, position: number): void {
 *     const tr = this.view.state.tr
 *     tr.insert(position, node)
 *     this.view.dispatch(tr)
 *   }
 *   // ... other methods
 * }
 *
 * // Use case depends on interface
 * class StreamAgentResponse {
 *   constructor(private editor: EditorAdapter) {}
 *
 *   async execute(queryId: string, chunk: string): Promise<void> {
 *     // Use editor abstraction
 *   }
 * }
 * ```
 *
 * @module application/interfaces
 */

/**
 * Selection information in the editor
 */
export interface EditorSelection {
  /** Start position of the selection (anchor) */
  from: number
  /** End position of the selection (head) */
  to: number
}

/**
 * Interface for editor operations
 *
 * Abstracts the editor API (ProseMirror/Milkdown) to enable clean architecture
 * and testability.
 */
export interface EditorAdapter {
  /**
   * Insert a node into the editor at a specific position
   *
   * @param node - The node to insert (editor-specific node type)
   * @param position - The position to insert at (0-based index)
   *
   * @example
   * ```typescript
   * const agentResponseNode = schema.nodes.agent_response.create({
   *   nodeId: 'query-123',
   *   state: 'loading'
   * })
   * editor.insertNode(agentResponseNode, 10)
   * ```
   */
  insertNode(node: any, position: number): void

  /**
   * Delete a range of content from the editor
   *
   * @param from - Start position of the range (inclusive)
   * @param to - End position of the range (exclusive)
   *
   * @example
   * ```typescript
   * // Delete characters from position 5 to 10
   * editor.deleteRange(5, 10)
   * ```
   */
  deleteRange(from: number, to: number): void

  /**
   * Get the current selection in the editor
   *
   * @returns The current selection range
   *
   * @example
   * ```typescript
   * const selection = editor.getSelection()
   * console.log(`Selected from ${selection.from} to ${selection.to}`)
   * ```
   */
  getSelection(): EditorSelection

  /**
   * Get text content from a specific range
   *
   * @param from - Start position of the range (inclusive)
   * @param to - End position of the range (exclusive)
   * @returns The text content in the range
   *
   * @example
   * ```typescript
   * const text = editor.getText(0, 10)
   * console.log(`First 10 characters: ${text}`)
   * ```
   */
  getText(from: number, to: number): string
}
