/**
 * LiveViewPushAdapter Tests
 *
 * Tests for the specialized adapter that provides type-safe wrappers around LiveViewEventBridge
 * for pushing structured events to Phoenix LiveView server.
 *
 * Test Strategy:
 * - Mock LiveViewEventBridge dependency
 * - Test type-safe helper methods for common event types
 * - Test payload validation before pushing
 * - Test proper delegation to bridge
 * - All tests use mocked bridge (infrastructure layer requirement)
 * - Tests execute in <100ms (infrastructure layer requirement)
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { LiveViewPushAdapter } from '../../../infrastructure/liveview/liveview-push-adapter'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'

describe('LiveViewPushAdapter', () => {
  let mockBridge: LiveViewBridge
  let adapter: LiveViewPushAdapter

  beforeEach(() => {
    mockBridge = {
      pushEvent: vi.fn().mockResolvedValue(undefined),
      handleEvent: vi.fn()
    }

    adapter = new LiveViewPushAdapter(mockBridge)
  })

  describe('constructor', () => {
    test('creates adapter with bridge', () => {
      expect(adapter).toBeDefined()
      expect(adapter).toBeInstanceOf(LiveViewPushAdapter)
    })

    test('stores reference to bridge', () => {
      expect((adapter as any).bridge).toBe(mockBridge)
    })
  })

  describe('pushYjsUpdate', () => {
    test('pushes yjs_update event with correct payload structure', async () => {
      const update = 'base64-update-data'
      const completeState = 'base64-complete-state'
      const userId = 'user-123'
      const markdown = '# Hello World'

      await adapter.pushYjsUpdate(update, completeState, userId, markdown)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('yjs_update', {
        update,
        complete_state: completeState,
        user_id: userId,
        markdown
      })
    })

    test('validates update is not empty', async () => {
      await expect(
        adapter.pushYjsUpdate('', 'state', 'user-123', 'markdown')
      ).rejects.toThrow('Update cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates completeState is not empty', async () => {
      await expect(
        adapter.pushYjsUpdate('update', '', 'user-123', 'markdown')
      ).rejects.toThrow('Complete state cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates userId is not empty', async () => {
      await expect(
        adapter.pushYjsUpdate('update', 'state', '', 'markdown')
      ).rejects.toThrow('User ID cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('allows empty markdown', async () => {
      await adapter.pushYjsUpdate('update', 'state', 'user-123', '')

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('yjs_update', {
        update: 'update',
        complete_state: 'state',
        user_id: 'user-123',
        markdown: ''
      })
    })

    test('handles long update data', async () => {
      const longUpdate = 'a'.repeat(10000)
      const completeState = 'b'.repeat(10000)
      const markdown = '#'.repeat(5000)

      await adapter.pushYjsUpdate(longUpdate, completeState, 'user-123', markdown)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('yjs_update', {
        update: longUpdate,
        complete_state: completeState,
        user_id: 'user-123',
        markdown
      })
    })

    test('returns Promise that resolves', async () => {
      const result = adapter.pushYjsUpdate('update', 'state', 'user-123', 'markdown')

      await expect(result).resolves.toBeUndefined()
    })
  })

  describe('pushAwarenessUpdate', () => {
    test('pushes awareness_update event with correct payload structure', async () => {
      const update = 'base64-awareness-data'
      const userId = 'user-456'

      await adapter.pushAwarenessUpdate(update, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('awareness_update', {
        update,
        user_id: userId
      })
    })

    test('validates update is not empty', async () => {
      await expect(
        adapter.pushAwarenessUpdate('', 'user-123')
      ).rejects.toThrow('Update cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates userId is not empty', async () => {
      await expect(
        adapter.pushAwarenessUpdate('update', '')
      ).rejects.toThrow('User ID cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('handles long awareness data', async () => {
      const longUpdate = JSON.stringify({ data: 'x'.repeat(5000) })

      await adapter.pushAwarenessUpdate(longUpdate, 'user-123')

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('awareness_update', {
        update: longUpdate,
        user_id: 'user-123'
      })
    })

    test('returns Promise that resolves', async () => {
      const result = adapter.pushAwarenessUpdate('update', 'user-123')

      await expect(result).resolves.toBeUndefined()
    })
  })

  describe('pushAgentQuery', () => {
    test('pushes agent_query event with correct payload structure', async () => {
      const queryId = 'query-789'
      const mention = '@Agent'
      const query = 'What is the meaning of life?'

      await adapter.pushAgentQuery(queryId, mention, query)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('agent_query', {
        query_id: queryId,
        mention,
        query
      })
    })

    test('validates queryId is not empty', async () => {
      await expect(
        adapter.pushAgentQuery('', '@Agent', 'query')
      ).rejects.toThrow('Query ID cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates mention is not empty', async () => {
      await expect(
        adapter.pushAgentQuery('query-123', '', 'query')
      ).rejects.toThrow('Mention cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates query is not empty', async () => {
      await expect(
        adapter.pushAgentQuery('query-123', '@Agent', '')
      ).rejects.toThrow('Query cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('handles long query text', async () => {
      const longQuery = 'What about '.repeat(1000)

      await adapter.pushAgentQuery('query-123', '@Agent', longQuery)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('agent_query', {
        query_id: 'query-123',
        mention: '@Agent',
        query: longQuery
      })
    })

    test('handles special characters in query', async () => {
      const specialQuery = 'Query with @#$%^&*() and émojis 🚀'

      await adapter.pushAgentQuery('query-123', '@Agent', specialQuery)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('agent_query', {
        query_id: 'query-123',
        mention: '@Agent',
        query: specialQuery
      })
    })

    test('returns Promise that resolves', async () => {
      const result = adapter.pushAgentQuery('query-123', '@Agent', 'query')

      await expect(result).resolves.toBeUndefined()
    })
  })

  describe('pushChatMessage', () => {
    test('pushes chat_message event with correct payload structure', async () => {
      const message = 'Hello, world!'
      const userId = 'user-123'

      await adapter.pushChatMessage(message, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('chat_message', {
        message,
        user_id: userId
      })
    })

    test('validates message is not empty', async () => {
      await expect(
        adapter.pushChatMessage('', 'user-123')
      ).rejects.toThrow('Message cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('validates userId is not empty', async () => {
      await expect(
        adapter.pushChatMessage('message', '')
      ).rejects.toThrow('User ID cannot be empty')

      expect(mockBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('handles multiline messages', async () => {
      const multilineMessage = 'Line 1\nLine 2\nLine 3'

      await adapter.pushChatMessage(multilineMessage, 'user-123')

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('chat_message', {
        message: multilineMessage,
        user_id: 'user-123'
      })
    })

    test('handles long messages', async () => {
      const longMessage = 'This is a very long message. '.repeat(100)

      await adapter.pushChatMessage(longMessage, 'user-123')

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('chat_message', {
        message: longMessage,
        user_id: 'user-123'
      })
    })

    test('handles special characters and unicode', async () => {
      const specialMessage = 'Hello 世界! 🌍 @user #tag'

      await adapter.pushChatMessage(specialMessage, 'user-123')

      expect(mockBridge.pushEvent).toHaveBeenCalledWith('chat_message', {
        message: specialMessage,
        user_id: 'user-123'
      })
    })

    test('returns Promise that resolves', async () => {
      const result = adapter.pushChatMessage('message', 'user-123')

      await expect(result).resolves.toBeUndefined()
    })
  })

  describe('error handling', () => {
    test('propagates bridge push errors for yjs update', async () => {
      const error = new Error('Network error')
      vi.mocked(mockBridge.pushEvent).mockRejectedValue(error)

      await expect(
        adapter.pushYjsUpdate('update', 'state', 'user-123', 'markdown')
      ).rejects.toThrow('Network error')
    })

    test('propagates bridge push errors for awareness update', async () => {
      const error = new Error('Connection lost')
      vi.mocked(mockBridge.pushEvent).mockRejectedValue(error)

      await expect(
        adapter.pushAwarenessUpdate('update', 'user-123')
      ).rejects.toThrow('Connection lost')
    })

    test('propagates bridge push errors for agent query', async () => {
      const error = new Error('Server error')
      vi.mocked(mockBridge.pushEvent).mockRejectedValue(error)

      await expect(
        adapter.pushAgentQuery('query-123', '@Agent', 'query')
      ).rejects.toThrow('Server error')
    })

    test('propagates bridge push errors for chat message', async () => {
      const error = new Error('Timeout')
      vi.mocked(mockBridge.pushEvent).mockRejectedValue(error)

      await expect(
        adapter.pushChatMessage('message', 'user-123')
      ).rejects.toThrow('Timeout')
    })
  })

  describe('integration', () => {
    test('can push multiple events in sequence', async () => {
      await adapter.pushYjsUpdate('update', 'state', 'user-123', 'markdown')
      await adapter.pushAwarenessUpdate('awareness', 'user-123')
      await adapter.pushAgentQuery('query-1', '@Agent', 'question')
      await adapter.pushChatMessage('hello', 'user-123')

      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(4)
    })

    test('validates all parameters before any push', async () => {
      // First push succeeds
      await adapter.pushChatMessage('message', 'user-123')

      // Second push fails validation
      await expect(
        adapter.pushChatMessage('', 'user-123')
      ).rejects.toThrow()

      // Only first push went through
      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(1)
    })
  })
})
