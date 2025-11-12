/**
 * UpdateCursorPosition Use Case
 *
 * Orchestrates updating a user's cursor position in the awareness state.
 * This use case updates the local awareness to reflect the current cursor position.
 *
 * Following Clean Architecture:
 * - Depends on interface (AwarenessAdapter), not concrete implementation
 * - Handles orchestration and validation
 * - Simple, focused responsibility (single use case)
 * - No external side effects beyond awareness update
 *
 * @example
 * ```typescript
 * const awarenessAdapter = new YjsAwarenessAdapter(awareness)
 * const useCase = new UpdateCursorPosition(awarenessAdapter)
 *
 * const userId = new UserId('user-123')
 *
 * // Update cursor to position 42
 * await useCase.execute(userId, 42)
 * ```
 *
 * @module application/use-cases
 */

import type { AwarenessAdapter } from '../interfaces/awareness-adapter.interface'
import { UserId } from '../../domain/value-objects/user-id'

export class UpdateCursorPosition {
  /**
   * Creates a new UpdateCursorPosition use case
   *
   * @param awarenessAdapter - Adapter for awareness operations (injected)
   */
  constructor(private readonly awarenessAdapter: AwarenessAdapter) {}

  /**
   * Execute the update cursor position use case
   *
   * Validates the position and updates the local awareness state
   * with the user's cursor position.
   *
   * @param userId - User ID whose cursor is being updated
   * @param position - The new cursor position (must be non-negative)
   * @returns Promise that resolves when update is complete
   * @throws Error if position is negative
   */
  async execute(userId: UserId, position: number): Promise<void> {
    // Validate position
    if (position < 0) {
      throw new Error('Cursor position must be non-negative')
    }

    // Update awareness with cursor position
    this.awarenessAdapter.setLocalState({
      userId: userId.value,
      cursor: position
    })
  }
}
