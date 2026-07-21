# Session-Based Chat History — Design Spec

## Overview

Replace the flat history list with a session-based conversation system modeled after chat apps. Users manually start and end sessions. Each session stores its messages persistently via SwiftData. Sessions can be viewed as read-only bubble history, then resumed into the live conversation view.

## Principles

- **YAGNI** — only what's needed for session + message CRUD
- **SwiftData** over Core Data (modern, native, Swift-first)
- **Airbnb Swift Style** — `final class`, `weak`, guard, computed properties over stored
- **Reusable component** — `MessageBubbleView` used in both history detail and live conversation

---

## Models

### `MessageRole`

```swift
enum MessageRole: String, Codable, Sendable {
    case sign    // Teman Tuli — bubble di kiri
    case speech  // Caregiver — bubble di kanan
}
```

### `ChatSession`

```swift
@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String?
    var createdAt: Date
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]

    var isActive: Bool { endedAt == nil }
    var messageCount: Int { messages.count }
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(createdAt)
    }

    init(id: UUID = UUID(), title: String? = nil, createdAt: Date = .now)
}
```

### `ChatMessage`

```swift
@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var content: String
    var role: MessageRole
    var createdAt: Date
    var session: ChatSession?

    init(id: UUID = UUID(), content: String, role: MessageRole, createdAt: Date = .now)
}
```

### Migration

Existing `Conversation` model + `conversationHistory` array in `AppStore` are replaced. No data migration needed (no prior persistence).

---

## Service Layer

### `SessionService`

Single-responsibility CRUD for sessions, isolated from view state.

```swift
@MainActor
final class SessionService {
    private let container: ModelContainer

    func createSession(title: String?) -> ChatSession
    func endSession(_ session: ChatSession)
    func deleteSession(_ session: ChatSession)
    func deleteMessage(_ message: ChatMessage)

    func allSessions() -> [ChatSession]
    func activeSession() -> ChatSession?
    func messages(for session: ChatSession) -> [ChatMessage]
}
```

---

## View Hierarchy

```
SessionListView (replaces HistoryView)
  └─ NavigationStack
       ├─ List of all sessions (title, date, message count, duration)
       └─ NavigationLink → SessionDetailView

SessionDetailView
  ├─ ScrollView of MessageBubbleView (read-only, grouped by role)
  └─ Button "Lanjutkan Percakapan" → set active session, navigate to UnifiedView

UnifiedView (updated)
  ├─ Camera preview + controls (unchanged)
  ├─ Session toolbar: [Start Session] / [End Session] toggle + active session label
  └─ ScrollView of MessageBubbleView (live)
       ├─ sign bubble → left-aligned, blue accent
       └─ speech bubble → right-aligned, green accent
```

### `MessageBubbleView`

```swift
struct MessageBubbleView: View {
    let content: String
    let role: MessageRole
    let timestamp: Date
    var isPending: Bool = false  // untuk real-time transcription
}
```

- `role == .sign`: trailing alignment, left bubble
- `role == .speech`: leading alignment, right bubble
- `isPending`: animasi pulse/opacity untuk transkripsi yang belum final

---

## Data Flow

```
User taps "Start Session"
  → SessionService.createSession()
  → set activeSessionId di AppStore
  → messages appended to active session via AppStore

User taps "End Session"
  → SessionService.endSession()
  → clear activeSessionId

User taps session di SessionListView
  → SessionDetailView loads messages for that session
  → "Lanjutkan" sets activeSessionId, navigates to UnifiedView
```

### AppStore changes

| Property | Role |
|----------|------|
| `sessionService: SessionService` | persisted CRUD |
| `activeSessionId: UUID?` | nil saat tidak ada session aktif |
| `messages: [ChatMessage]` | computed from active session |

---

## Files to Create

1. `SignLanguageApp/Models/ChatSession.swift`
2. `SignLanguageApp/Models/ChatMessage.swift`
3. `SignLanguageApp/Models/MessageRole.swift`
4. `SignLanguageApp/Services/SessionService.swift`
5. `SignLanguageApp/Features/Session/SessionListView.swift`
6. `SignLanguageApp/Features/Session/SessionDetailView.swift`
7. `SignLanguageApp/Features/Conversation/Components/MessageBubbleView.swift`

## Files to Modify

1. `SignLanguageApp/Services/Pipeline/AppStore.swift` — add `sessionService`, `activeSessionId`, update `addToHistory`
2. `SignLanguageApp/Features/Unified/UnifiedView.swift` — replace conversation section with bubble layout + session controls
3. `SignLanguageApp/Features/History/HistoryView.swift` — this file is **replaced** by `SessionListView`
4. `SignLanguageApp/App/SignLanguageApp.swift` — inject `ModelContainer` at app level

## Deleted

1. `SignLanguageApp/Models/Conversation.swift` — replaced by `ChatMessage` + `ChatSession`
2. `SignLanguageApp/Features/History/HistoryView.swift` — replaced by `SessionListView`

---

## Scope / Non-Goals

- No search, no pagination (SwiftData lazy loads)
- No multi-device sync (CloudKit)
- No rich media (images, audio clips)
- No "typing indicator" beyond `isPending` flag

Add when needed.
