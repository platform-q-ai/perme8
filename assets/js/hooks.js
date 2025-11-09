/**
 * Hooks Entry Point
 *
 * This file serves as the main entry point for all Phoenix LiveView hooks.
 * Hooks are organized by domain into separate files for better maintainability.
 */

// Editor and page hooks
export { MilkdownEditor, PageTitleInput } from './page_hooks'

// Chat hooks
export { ChatPanel, ChatMessages, ChatInput } from './chat_hooks'

// Flash hooks
export { AutoHideFlash } from './flash_hooks'

// Default export for Phoenix LiveView
import { MilkdownEditor, PageTitleInput } from './page_hooks'
import { ChatPanel, ChatMessages, ChatInput } from './chat_hooks'
import { AutoHideFlash } from './flash_hooks'

export default {
  MilkdownEditor,
  ChatPanel,
  ChatMessages,
  ChatInput,
  AutoHideFlash,
  PageTitleInput
}
