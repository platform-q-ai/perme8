/**
 * BroadcastAwareness Use Case
 *
 * Orchestrates broadcasting user awareness (cursor/selection) to other participants.
 * This use case coordinates between the AwarenessAdapter and LiveViewBridge.
 *
 * Following Clean Architecture:
 * - Depends on interfaces (AwarenessAdapter, LiveViewBridge), not concrete implementations
 * - Handles orchestration and side effects
 * - No business logic (that's in domain layer)
 * - Converts between domain types and infrastructure formats (binary to base64)
 *
 * @example
 * ```typescript
 * const awarenessAdapter = new YjsAwarenessAdapter(awareness)
 * const liveViewBridge = new PhoenixLiveViewBridge(hook)
 * const useCase = new BroadcastAwareness(awarenessAdapter, liveViewBridge)
 *
 * const userAwareness = UserAwareness.create(userId, userName, userColor)
 * const withCursor = userAwareness.updateCursor(42)
 *
 * await useCase.execute(withCursor)
 * ```
 *
 * @module application/use-cases
 */

import type { AwarenessAdapter } from '../interfaces/awareness-adapter.interface'
import type { LiveViewBridge } from '../interfaces/liveview-bridge.interface'
import { UserAwareness } from '../../domain/entities/user-awareness'

export class BroadcastAwareness {
  /**
   * Creates a new BroadcastAwareness use case
   *
   * @param awarenessAdapter - Adapter for awareness operations (injected)
   * @param liveViewBridge - Bridge for LiveView communication (injected)
   */
  constructor(
    private readonly awarenessAdapter: AwarenessAdapter,
    private readonly liveViewBridge: LiveViewBridge
  ) {}

  /**
   * Execute the broadcast awareness use case
   *
   * Encodes the awareness update and broadcasts it to other participants
   * via the LiveView server.
   *
   * @param userAwareness - The user awareness to broadcast
   * @returns Promise that resolves when broadcast is complete
   * @throws Error if encoding or broadcasting fails
   */
  async execute(userAwareness: UserAwareness): Promise<void> {
    // Encode awareness update for all clients (empty array means all)
    const update = this.awarenessAdapter.encodeUpdate([])

    // Convert binary update to base64 for transport
    const updateBase64 = this.encodeToBase64(update)

    // Broadcast via LiveView
    await this.liveViewBridge.pushEvent('awareness-update', {
      userId: userAwareness.userId.value,
      update: updateBase64
    })
  }

  /**
   * Encode Uint8Array to base64 string
   *
   * @param data - Binary data to encode
   * @returns Base64-encoded string
   */
  private encodeToBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data))
  }
}
