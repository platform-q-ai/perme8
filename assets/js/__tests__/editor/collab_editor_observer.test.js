import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { observeCollabEditor } from '../../editor/collab_editor_observer'

describe('Collab Editor Observer', () => {
  let mockSection
  let mockEditorDiv
  let observerCallback
  let mockObserver
  let observerOptions

  beforeEach(() => {
    // Create mock section
    mockSection = document.createElement('section')
    mockSection.setAttribute('data-collab-editor-section', '')

    // Create mock editor div with paused animation class
    mockEditorDiv = document.createElement('div')
    mockEditorDiv.classList.add('collab-editor-animations-paused')

    mockSection.appendChild(mockEditorDiv)
    document.body.appendChild(mockSection)

    // Mock IntersectionObserver
    mockObserver = {
      observe: vi.fn(),
      unobserve: vi.fn(),
      disconnect: vi.fn()
    }

    global.IntersectionObserver = class {
      constructor(callback, options) {
        observerCallback = callback
        observerOptions = options
        Object.assign(this, mockObserver)
      }
    }
  })

  afterEach(() => {
    if (document.body.contains(mockSection)) {
      document.body.removeChild(mockSection)
    }
  })

  describe('observeCollabEditor', () => {
    it('should return early if section does not exist', () => {
      // Remove section
      document.body.removeChild(mockSection)

      observeCollabEditor()

      // Observer should not be created (callback not set)
      expect(observerCallback).toBeUndefined()
    })

    it('should create IntersectionObserver with correct options', () => {
      observeCollabEditor()

      // Check that options were passed correctly
      expect(observerOptions).toEqual({
        threshold: 0.3,
        rootMargin: '0px'
      })
    })

    it('should observe the collab section', () => {
      observeCollabEditor()

      expect(mockObserver.observe).toHaveBeenCalledWith(mockSection)
    })

    it('should start animations when section is intersecting', () => {
      observeCollabEditor()

      // Simulate intersection
      const entries = [{
        target: mockSection,
        isIntersecting: true
      }]

      observerCallback(entries)

      expect(mockEditorDiv.classList.contains('collab-editor-animations-paused')).toBe(false)
      expect(mockEditorDiv.classList.contains('collab-editor-animations-active')).toBe(true)
    })

    it('should not start animations when section is not intersecting', () => {
      observeCollabEditor()

      // Simulate not intersecting
      const entries = [{
        target: mockSection,
        isIntersecting: false
      }]

      observerCallback(entries)

      expect(mockEditorDiv.classList.contains('collab-editor-animations-paused')).toBe(true)
      expect(mockEditorDiv.classList.contains('collab-editor-animations-active')).toBe(false)
    })

    it('should handle missing editor div gracefully', () => {
      // Remove editor div
      mockSection.removeChild(mockEditorDiv)

      observeCollabEditor()

      const entries = [{
        target: mockSection,
        isIntersecting: true
      }]

      expect(() => {
        observerCallback(entries)
      }).not.toThrow()
    })

    it('should handle multiple entries', () => {
      const secondSection = document.createElement('section')
      secondSection.setAttribute('data-collab-editor-section', '')

      const secondEditorDiv = document.createElement('div')
      secondEditorDiv.classList.add('collab-editor-animations-paused')

      secondSection.appendChild(secondEditorDiv)
      document.body.appendChild(secondSection)

      observeCollabEditor()

      const entries = [
        {
          target: mockSection,
          isIntersecting: true
        },
        {
          target: secondSection,
          isIntersecting: false
        }
      ]

      observerCallback(entries)

      // First should have animations active
      expect(mockEditorDiv.classList.contains('collab-editor-animations-active')).toBe(true)

      // Second should still be paused
      expect(secondEditorDiv.classList.contains('collab-editor-animations-paused')).toBe(true)
      expect(secondEditorDiv.classList.contains('collab-editor-animations-active')).toBe(false)

      // Cleanup
      document.body.removeChild(secondSection)
    })

    it('should only activate animations on first intersection', () => {
      observeCollabEditor()

      // First intersection
      const entries = [{
        target: mockSection,
        isIntersecting: true
      }]

      observerCallback(entries)

      expect(mockEditorDiv.classList.contains('collab-editor-animations-active')).toBe(true)

      // Remove active class and add paused again
      mockEditorDiv.classList.remove('collab-editor-animations-active')
      mockEditorDiv.classList.add('collab-editor-animations-paused')

      // Second intersection
      observerCallback(entries)

      // Should activate again (not configured to stop observing)
      expect(mockEditorDiv.classList.contains('collab-editor-animations-active')).toBe(true)
    })

    it('should use correct threshold value', () => {
      observeCollabEditor()

      expect(observerOptions.threshold).toBe(0.3)
    })

    it('should use correct rootMargin value', () => {
      observeCollabEditor()

      expect(observerOptions.rootMargin).toBe('0px')
    })
  })
})
