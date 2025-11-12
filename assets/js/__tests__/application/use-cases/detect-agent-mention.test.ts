import { describe, test, expect, vi, beforeEach } from 'vitest'
import { DetectAgentMention } from '../../../application/use-cases/detect-agent-mention'
import { MentionDetectionPolicy } from '../../../domain/policies/mention-detection-policy'
import { MentionPattern } from '../../../domain/value-objects/mention-pattern'
import type { IMentionDetectionAdapter } from '../../../application/interfaces/mention-detection-adapter'

describe('DetectAgentMention', () => {
  let mockAdapter: IMentionDetectionAdapter
  let policy: MentionDetectionPolicy
  let useCase: DetectAgentMention

  beforeEach(() => {
    mockAdapter = {
      detectAtCursor: vi.fn(),
      hasMentionAtCursor: vi.fn()
    }

    const pattern = new MentionPattern('@j')
    policy = new MentionDetectionPolicy(pattern)
    useCase = new DetectAgentMention(policy, mockAdapter)
  })

  describe('execute', () => {
    test('returns null when no mention at cursor', () => {
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(null)

      const result = useCase.execute()

      expect(result).toBeNull()
      expect(mockAdapter.detectAtCursor).toHaveBeenCalled()
    })

    test('returns null when mention has no question', () => {
      const detection = { from: 0, to: 3, text: '@j ' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.execute()

      expect(result).toBeNull()
    })

    test('returns detection when valid mention found', () => {
      const detection = { from: 0, to: 22, text: '@j what is TypeScript?' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.execute()

      expect(result).toEqual(detection)
    })

    test('returns null for whitespace-only question', () => {
      const detection = { from: 0, to: 10, text: '@j        ' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.execute()

      expect(result).toBeNull()
    })
  })

  describe('hasValidMention', () => {
    test('returns false when no mention at cursor', () => {
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(null)

      const result = useCase.hasValidMention()

      expect(result).toBe(false)
    })

    test('returns false when mention has no question', () => {
      const detection = { from: 0, to: 3, text: '@j ' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.hasValidMention()

      expect(result).toBe(false)
    })

    test('returns true when valid mention found', () => {
      const detection = { from: 0, to: 22, text: '@j what is TypeScript?' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.hasValidMention()

      expect(result).toBe(true)
    })
  })

  describe('extractQuestion', () => {
    test('returns null when no mention at cursor', () => {
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(null)

      const result = useCase.extractQuestion()

      expect(result).toBeNull()
    })

    test('extracts question from valid mention', () => {
      const detection = { from: 0, to: 22, text: '@j what is TypeScript?' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.extractQuestion()

      expect(result).toBe('what is TypeScript?')
    })

    test('returns null for empty question', () => {
      const detection = { from: 0, to: 3, text: '@j ' }
      vi.mocked(mockAdapter.detectAtCursor).mockReturnValue(detection)

      const result = useCase.extractQuestion()

      expect(result).toBeNull()
    })
  })
})
