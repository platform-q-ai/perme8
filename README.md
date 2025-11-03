# Phoenix Milkdown - Collaborative Markdown Editor

A real-time collaborative WYSIWYG markdown editor built with Phoenix LiveView, Milkdown, and Yjs.

## Features

- **Real-time Collaboration**: Multiple users can edit the same document simultaneously
- **Yjs CRDT**: Conflict-free collaboration using Yjs (no operational transformation needed!)
- **LiveView Transport**: Uses Phoenix LiveView's WebSocket for Yjs update synchronization
- **Milkdown WYSIWYG Editor**: Modern, plugin-driven WYSIWYG markdown editor
- **Phoenix LiveView**: Server-rendered UI with real-time updates via WebSockets
- **Nord Theme**: Beautiful Nord theme for comfortable editing
- **Rich Text Editing**: See your markdown rendered as you type (headings, bold, lists, etc.)
- **Built-in Undo/Redo**: Standard keyboard shortcuts (Ctrl+Z, Ctrl+Shift+Z) work out of the box
- **Zero Conflict Resolution**: Yjs automatically handles all concurrent edits

## Architecture

### Components

1. **LiveView (`EditorLive`)**: Manages real-time synchronization transport
   - Handles PubSub subscriptions for document channels
   - Broadcasts Yjs updates to all connected clients
   - Stores initial documents in `:persistent_term` (demo purposes)
   - Acts as transport layer for Yjs (no manual conflict resolution!)

2. **JavaScript Hook (`MilkdownEditor`)**: Bridges LiveView with Milkdown + Yjs
   - Initializes Milkdown editor with CommonMark preset and Yjs collab plugin
   - Creates Yjs document and shared ProseMirror fragment
   - Sends Yjs binary updates through Phoenix LiveView
   - Applies remote Yjs updates from other clients
   - Uses `phx-update="ignore"` to prevent LiveView from interfering

3. **Yjs Document**: CRDT-based shared editing
   - Manages concurrent editing with automatic conflict resolution
   - Tracks document state as sequence of operations
   - Handles merging of concurrent changes
   - Provides undo/redo management (we use custom implementation)

### Data Flow (with Yjs)

```
User types in Milkdown WYSIWYG editor
  ↓
Yjs detects ProseMirror changes and creates update
  ↓
Update encoded to binary and base64-encoded
  ↓
pushEvent("yjs_update", {update, user_id}) → LiveView
  ↓
Server broadcasts update via PubSub (no transformation needed!)
  ↓
Phoenix.PubSub.broadcast_from(update)
  ↓
Other clients receive via handle_info
  ↓
Client decodes update and applies to local Yjs document
  ↓
Yjs automatically merges changes and updates Milkdown
  ↓
✅ Perfect convergence! No conflicts!
```

### Why Yjs?

**CRDTs (Conflict-free Replicated Data Types)** like Yjs provide automatic conflict resolution:

- ✅ **No Manual Transformation**: Yjs handles all concurrent editing automatically
- ✅ **Perfect Convergence**: All clients always converge to the same state
- ✅ **Efficient Updates**: Only sends delta updates, not full document
- ✅ **Network Independence**: Works with any transport (we use Phoenix LiveView)
- ✅ **Undo Manager**: Built-in undo/redo (we use custom for independence)

## Getting Started

### Prerequisites

- Elixir 1.19+ and Erlang 28+
- Node.js 18+ (for asset compilation)

### Installation

1. Install dependencies:
```bash
mix deps.get
cd assets && npm install
```

2. Start the Phoenix server:
```bash
mix phx.server
```

3. Visit [`localhost:4000/editor`](http://localhost:4000/editor) in your browser

### Testing Collaboration

1. Open the editor in your browser: `http://localhost:4000/editor`
2. Note the Document ID in the header
3. Open the same URL in another browser window or tab
4. Start typing in either window - changes will appear in real-time on both!

You can also share specific documents by using the URL format: `http://localhost:4000/editor/{doc_id}`

## Project Structure

```
lib/
├── jarga_web/
│   ├── live/
│   │   └── editor_live.ex          # LiveView module for Yjs transport
│   └── router.ex                    # Routes configuration
assets/
├── js/
│   ├── app.js                       # Main JavaScript entry point
│   └── hooks.js                     # LiveView hooks (Milkdown + Yjs integration)
└── css/
    └── app.css                      # Styles
```

## Technical Details

### Synchronization Strategy

This application uses **Yjs CRDT** with **Phoenix LiveView as transport**:
- Yjs document maintains the collaborative state
- Yjs automatically handles conflict resolution (CRDTs!)
- Phoenix LiveView WebSocket transports Yjs binary updates
- Server acts as message broker (no transformation logic needed)
- Perfect convergence guaranteed by Yjs

### State Management

- **Client-side**: Each client has a Yjs document that stays in sync
- **Server-side**: Phoenix LiveView broadcasts Yjs updates through PubSub
- **Storage**: Yjs updates stored in `:persistent_term` (for demo; use ETS/Redis in production)

### Real-time Communication

- **Transport**: Phoenix LiveView WebSocket (reuses existing connection!)
- **PubSub**: Each document has its own topic (`document:{doc_id}`)
- **Broadcast**: Yjs updates broadcast to all subscribers except the originator
- **Encoding**: Binary Yjs updates encoded as base64 for transport

### WYSIWYG Experience

Milkdown provides a rich text editing experience:
- **Visual Feedback**: See headings, bold, italic, and other formatting rendered as you type
- **Familiar Interface**: Similar to popular editors like Notion or Typora
- **Markdown Under the Hood**: All content is stored and transmitted as markdown
- **Plugin Architecture**: Extensible through Milkdown's plugin system
- **Yjs Integration**: Seamless collaboration through Milkdown's collab plugin

### Undo/Redo

Uses Milkdown's built-in history plugin:

- ✅ **Standard Keyboard Shortcuts**: Ctrl+Z (undo), Ctrl+Shift+Z or Ctrl+Y (redo)
- ✅ **ProseMirror History**: Leverages ProseMirror's battle-tested history plugin
- ✅ **Works with Collaboration**: History plugin is aware of collaborative changes
- ✅ **Automatic**: No custom code needed!

## Production Considerations

For production deployment, consider:

1. **Persistent Storage**: Replace `:persistent_term` with Ecto, ETS, or Redis
2. **Yjs Persistence**: Store Yjs document state for new clients joining late
3. **Document Cleanup**: Implement garbage collection for inactive documents
4. **Authentication**: Add user authentication and document permissions
5. **Presence**: Use Phoenix.Presence to show active users
6. **Performance**: Optimize for large documents and many concurrent users
7. **Rate Limiting**: Add rate limiting to prevent abuse
8. **Yjs Awareness**: Add cursor positions and user presence with Yjs Awareness API
9. **Compression**: Compress Yjs updates for reduced bandwidth

## Learn More

- Phoenix Framework: https://www.phoenixframework.org/
- Phoenix LiveView: https://hexdocs.pm/phoenix_live_view
- Milkdown: https://milkdown.dev/
- Yjs: https://yjs.dev/
- Phoenix PubSub: https://hexdocs.pm/phoenix_pubsub
