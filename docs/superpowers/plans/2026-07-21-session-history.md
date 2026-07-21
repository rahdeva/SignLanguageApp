# Session-Based Chat History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flat history with persistent session-based conversation system using SwiftData.

**Architecture:** SwiftData models (`ChatSession`, `ChatMessage`) with `@Model` macros, `SessionService` for CRUD isolation, `MessageBubbleView` reusable component shared between history detail and live conversation. Manual start/end session via toolbar. Sign bubble left-aligned, speech bubble right-aligned.

**Tech Stack:** SwiftData, SwiftUI, iOS 26.5+, Observation framework

## Global Constraints

- All Swift files follow Airbnb Swift style guide
- `final class` for all classes
- `weak` over `unowned`
- SwiftData for persistence (no Core Data/UserDefaults for messages)
- Reuse existing services (`AppStore`, `CameraService`, `SpeechRecognizerService`, etc.) — no duplicate
- Existing `Conversation.swift` model file will be deleted (replaced by `ChatMessage` + `ChatSession`)
- Existing `HistoryView.swift` file will be deleted (replaced by `SessionListView`)

---

### Task 1: Create SwiftData Models

**Files:**
- Create: `SignLanguageApp/Models/MessageRole.swift`
- Create: `SignLanguageApp/Models/ChatMessage.swift`
- Create: `SignLanguageApp/Models/ChatSession.swift`
- Delete: `SignLanguageApp/Models/Conversation.swift`

**Interfaces:**
- Consumes: nothing from prior tasks
- Produces: `MessageRole` enum (`.sign`, `.speech`), `ChatSession` model, `ChatMessage` model

- [ ] **Step 1: Create `MessageRole.swift`**

```swift
//
//  MessageRole.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation

enum MessageRole: String, Codable, Sendable {
    /// Sign language (Teman Tuli) — bubble on the left.
    case sign
    /// Speech-to-text (Caregiver) — bubble on the right.
    case speech
}
```

- [ ] **Step 2: Create `ChatMessage.swift`**

```swift
//
//  ChatMessage.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var content: String
    var role: MessageRole
    var createdAt: Date
    var session: ChatSession?

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 3: Create `ChatSession.swift`**

```swift
//
//  ChatSession.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

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

    init(
        id: UUID = UUID(),
        title: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Delete `Conversation.swift`**

```bash
rm SignLanguageApp/Models/Conversation.swift
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: create SwiftData models ChatSession, ChatMessage, MessageRole

Replace existing Conversation model with persistent session-based models.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Create SessionService

**Files:**
- Create: `SignLanguageApp/Services/SessionService.swift`

**Interfaces:**
- Consumes: `ChatSession`, `ChatMessage`, `MessageRole` (from Task 1)
- Produces: `SessionService` with `createSession()`, `endSession()`, `deleteSession()`, `allSessions()`, `activeSession()`, `messages(for:)`, `appendMessage(to:content:role:)`

- [ ] **Step 1: Create `SessionService.swift`**

```swift
//
//  SessionService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

@MainActor
final class SessionService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Sessions

    func createSession(title: String? = nil) -> ChatSession {
        let session = ChatSession(title: title)
        container.mainContext.insert(session)
        try? container.mainContext.save()
        return session
    }

    func endSession(_ session: ChatSession) {
        session.endedAt = .now
        try? container.mainContext.save()
    }

    func deleteSession(_ session: ChatSession) {
        container.mainContext.delete(session)
        try? container.mainContext.save()
    }

    func allSessions() -> [ChatSession] {
        let descriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    func activeSession() -> ChatSession? {
        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        return try? container.mainContext.fetch(descriptor).first
    }

    // MARK: - Messages

    func messages(for session: ChatSession) -> [ChatMessage] {
        session.messages.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func appendMessage(to session: ChatSession, content: String, role: MessageRole) -> ChatMessage {
        let message = ChatMessage(content: content, role: role)
        message.session = session
        session.messages.append(message)
        try? container.mainContext.save()
        return message
    }

    func deleteMessage(_ message: ChatMessage) {
        container.mainContext.delete(message)
        try? container.mainContext.save()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: create SessionService for SwiftData CRUD

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Create MessageBubbleView

**Files:**
- Create: `SignLanguageApp/Features/Conversation/Components/MessageBubbleView.swift`

**Interfaces:**
- Consumes: `MessageRole` (from Task 1)
- Produces: `MessageBubbleView` — reusable bubble component

- [ ] **Step 1: Create `MessageBubbleView.swift`**

```swift
//
//  MessageBubbleView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let content: String
    let role: MessageRole
    let timestamp: Date
    var isPending: Bool = false

    private var isLeftAligned: Bool { role == .sign }
    private var accentColor: Color { role == .sign ? .blue : .green }

    var body: some View {
        HStack {
            if !isLeftAligned { Spacer(minLength: 60) }

            VStack(alignment: isLeftAligned ? .leading : .trailing, spacing: 4) {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accentColor.opacity(isPending ? 0.6 : 1))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(alignment: isLeftAligned ? .bottomLeading : .bottomTrailing) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.caption)
                            .foregroundStyle(accentColor.opacity(isPending ? 0.6 : 1))
                            .offset(x: isLeftAligned ? 6 : -6, y: 4)
                    }

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if isLeftAligned { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
        .opacity(isPending ? 0.7 : 1)
    }
}

#Preview("Sign (left)") {
    VStack(spacing: 16) {
        MessageBubbleView(
            content: "Saya mau pergi ke rumah sakit",
            role: .sign,
            timestamp: .now
        )
        MessageBubbleView(
            content: "Oh baik, saya antar ya",
            role: .speech,
            timestamp: .now
        )
        MessageBubbleView(
            content: "Terima kasih...",
            role: .sign,
            timestamp: .now,
            isPending: true
        )
    }
    .padding()
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: create MessageBubbleView with sign left / speech right layout

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Create SessionListView

**Files:**
- Create: `SignLanguageApp/Features/Session/SessionListView.swift`
- Delete: `SignLanguageApp/Features/History/HistoryView.swift`

**Interfaces:**
- Consumes: `ChatSession` (from Tasks 1)
- Produces: `SessionListView` — replacement for `HistoryView`, uses `@Query` for SwiftData reactivity

- [ ] **Step 1: Create `SessionListView.swift`**

```swift
//
//  SessionListView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftData
import SwiftUI

struct SessionListView: View {
    @Query(sort: \ChatSession.createdAt, order: .reverse)
    private var sessions: [ChatSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("history.empty_title", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("history.empty_desc")
                    }
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("history.title")
        }
    }
}

private struct SessionRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title ?? "history.session_untitled")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if session.isActive {
                    Text("history.session_active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 8) {
                Text(session.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(session.messageCount) pesan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionListView()
}
```

- [ ] **Step 2: Delete `HistoryView.swift`**

```bash
rm SignLanguageApp/Features/History/HistoryView.swift
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: create SessionListView replacing HistoryView

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Create SessionDetailView

**Files:**
- Create: `SignLanguageApp/Features/Session/SessionDetailView.swift`

**Interfaces:**
- Consumes: `ChatSession`, `ChatMessage`, `MessageRole`, `MessageBubbleView` (from Tasks 1-3)
- Produces: `SessionDetailView` — read-only bubble history with "Lanjutkan" button

- [ ] **Step 1: Create `SessionDetailView.swift`**

```swift
//
//  SessionDetailView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: ChatSession
    var onResume: ((ChatSession) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(session.title ?? "history.session_untitled")
                    .font(.title2.weight(.semibold))
                Text(session.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let endedAt = session.endedAt {
                    let minutes = Int(endedAt.timeIntervalSince(session.createdAt) / 60)
                    Text("\(session.messageCount) pesan \(minutes > 0 ? "• \(minutes) menit" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.messages.sorted { $0.createdAt < $1.createdAt }) { message in
                        MessageBubbleView(
                            content: message.content,
                            role: message.role,
                            timestamp: message.createdAt
                        )
                    }
                }
                .padding(.vertical, 12)
            }

            Divider()

            // Resume button
            if session.endedAt != nil, let onResume {
                Button {
                    onResume(session)
                } label: {
                    Label("history.resume", systemImage: "arrow.forward.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle("history.detail_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: ChatSession())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: create SessionDetailView with read-only bubble history and resume button

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Update AppStore with Session Integration

**Files:**
- Modify: `SignLanguageApp/Services/Pipeline/AppStore.swift`

**Interfaces:**
- Consumes: `SessionService`, `ChatSession`, `ChatMessage`, `MessageRole` (from Tasks 1-2)
- Produces: Updated `AppStore` with `sessionService`, `activeSessionId`, session-aware `addToHistory()`

- [ ] **Step 1: Update `AppStore.swift`**

Replace file content:

```swift
//
//  AppStore.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Observation
import SwiftData

/// Central state coordinator. Owns all services and exposes reactive state to the view layer.
@MainActor
@Observable
final class AppStore {
    // MARK: - Services
    private(set) var cameraService: CameraService
    private(set) var speechService: SpeechRecognizerService
    private(set) var synthesizerService: SpeechSynthesizerService
    private(set) var inferencer: SignLanguageInferencing
    private(set) var sessionService: SessionService

    // MARK: - Language
    var languageSettings: LanguageSettings = LanguageSettings()

    // MARK: - Speech-to-Text
    var speechToTextOutput: String = ""
    var isTranscribing = false
    var isMicAuthorized = false

    // MARK: - Sign-to-Speech
    var signPredictionOutput: String = ""
    var isPredicting = false
    var isCameraAuthorized = false

    // MARK: - Session
    /// Active session ID — nil when no session is active.
    var activeSessionId: UUID?

    /// The currently active session, if any.
    var activeSession: ChatSession? {
        guard let id = activeSessionId else { return nil }
        return sessionService.allSessions().first { $0.id == id && $0.isActive }
    }

    /// All sessions from persistent storage.
    var allSessions: [ChatSession] { sessionService.allSessions() }

    // MARK: - Error
    var error: AppError?
    var showingError = false

    // MARK: - Init
    init(
        container: ModelContainer = try! ModelContainer(for: ChatSession.self, ChatMessage.self),
        inferencer: SignLanguageInferencing = SignLanguageInferencer()
    ) {
        self.inferencer = inferencer
        self.sessionService = SessionService(container: container)
        cameraService = CameraService()
        speechService = SpeechRecognizerService()
        synthesizerService = SpeechSynthesizerService()
    }

    // MARK: - Actions

    /// Check all permissions at launch. Individual services re-check on demand.
    func checkPermissions() async {
        isCameraAuthorized = await PermissionService.requestCamera()
        isMicAuthorized = await PermissionService.requestMicrophone()
        if isMicAuthorized {
            _ = await PermissionService.requestSpeech()
        }
    }

    func dismissError() {
        error = nil
        showingError = false
    }

    /// Start a new session.
    func startSession(title: String? = nil) {
        let session = sessionService.createSession(title: title)
        activeSessionId = session.id
    }

    /// End the current active session.
    func endSession() {
        guard let session = activeSession else { return }
        sessionService.endSession(session)
        activeSessionId = nil
    }

    /// Add a message to the active session. If no active session exists, creates one.
    func addToHistory(message: String, role: MessageRole) {
        let session: ChatSession
        if let existing = activeSession {
            session = existing
        } else {
            session = sessionService.createSession()
            activeSessionId = session.id
        }
        sessionService.appendMessage(to: session, content: message, role: role)
    }

    /// Resume a past session — sets it as the active session.
    func resumeSession(_ session: ChatSession) {
        session.endedAt = nil
        activeSessionId = session.id
        try? sessionService.container.mainContext.save()
    }

    /// Speak text aloud using the current TTS language setting.
    func speak(_ text: String) async {
        await synthesizerService.speak(text, language: languageSettings.ttsLanguage)
    }

    /// Stop speaking immediately.
    func stopSpeaking() {
        Task { await synthesizerService.stop() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: update AppStore with session service and session management

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Update RootView and App Entry Point

**Files:**
- Modify: `SignLanguageApp/App/SignLanguageApp.swift`
- Modify: `SignLanguageApp/Features/Content/RootView.swift`

**Interfaces:**
- Consumes: updated `AppStore` (from Task 6), `SessionListView` (from Task 4)
- Produces: App with `ModelContainer` injection and session-aware tab navigation

- [ ] **Step 1: Update `SignLanguageApp.swift`**

```swift
//
//  SignLanguageApp.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftData
import SwiftUI

/// App entry point. Root scene connects `AppStore` to the view hierarchy.
@main
struct SignLanguageApp: App {
    let container: ModelContainer = {
        guard let container = try? ModelContainer(for: ChatSession.self, ChatMessage.self) else {
            fatalError("Failed to create ModelContainer")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
```

- [ ] **Step 2: Update `RootView.swift`**

Replace the file content — update to pass `container`, replace `HistoryView()` with `SessionListView`, fix `addToHistory` calls:

```swift
//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftData
import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case conversation, history, settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .conversation: "tab.conversation"
        case .history:      "tab.history"
        case .settings:     "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .conversation: "person.2.wave.2"
        case .history:      "clock"
        case .settings:     "gearshape"
        }
    }
}

/// Root view — shows onboarding on first launch, then the tabbed main interface.
/// Injects both `AppStore` and the chosen `Locale` into the environment so all
/// child views automatically render in the correct language.
struct RootView: View {
    @State private var appStore: AppStore
    @State private var selectedTab: AppTab = .conversation
    @State private var showOnboarding = !UserDefaults.standard.bool(
        forKey: "hasSeenOnboarding"
    )

    init(container: ModelContainer) {
        _appStore = State(wrappedValue: AppStore(container: container))
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            } else {
                TabView(selection: $selectedTab) {
                    UnifiedView()
                        .tabItem {
                            Label(AppTab.conversation.titleKey, systemImage: AppTab.conversation.icon)
                        }
                        .tag(AppTab.conversation)

                    SessionListView()
                        .tabItem {
                            Label(AppTab.history.titleKey, systemImage: AppTab.history.icon)
                        }
                        .tag(AppTab.history)

                    SettingsView()
                        .tabItem {
                            Label(AppTab.settings.titleKey, systemImage: AppTab.settings.icon)
                        }
                        .tag(AppTab.settings)
                }
                .environment(appStore)
                .task { await appStore.checkPermissions() }
            }
        }
        .id(appStore.languageSettings.appLanguage)
        .environment(\.locale, appStore.languageSettings.appLanguage.locale)
        .animation(.default, value: showOnboarding)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: update app entry and root view with ModelContainer and SessionListView

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Update UnifiedView with Bubble Layout and Session Controls

**Files:**
- Modify: `SignLanguageApp/Features/Unified/UnifiedView.swift`

**Interfaces:**
- Consumes: `MessageBubbleView`, updated `AppStore`, `SessionService`, `ChatSession`, `ChatMessage`
- Produces: Updated `UnifiedView` with bubble layout + Start/End Session toolbar

- [ ] **Step 1: Update `UnifiedView.swift`**

Replace the entire file. Key changes:
- Conversation section becomes bubble layout (`MessageBubbleView`)
- Add session toolbar (Start/End Session buttons + active session indicator)
- Messages from active session shown as bubbles between camera pane and bottom controls

```swift
//
//  UnifiedView.swift
//  SignLanguageApp
//
//  Created by Dimas Prihady Setyawan on 19/07/26.
//

import SwiftUI

struct UnifiedView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 1,
        cooldownThreshold: 5,
        maxWords: 12
    )
    @State private var speechStore: SpeechToTextStore?
    @State private var lastAutoPlayedTemanTuliText: String?
    @State private var showConfidenceDetails = true
    @State private var showNewSessionAlert = false

    private var temanTuliText: String {
        recognizer.builtSentence
    }

    private var caregiverTranscribedText: String {
        speechStore?.transcribedText ?? appStore.speechToTextOutput
    }

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    /// Messages from the active session, sorted chronologically.
    private var sessionMessages: [ChatMessage] {
        guard let session = appStore.activeSession else { return [] }
        return session.messages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    cameraPane
                    signRecognitionControls
                    sessionToolbar
                    conversationSection
                }
            }

            // Bottom controls (mic, flip, etc.)
            bottomControlsBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .onAppear {
            if speechStore == nil {
                speechStore = SpeechToTextStore(appStore: appStore)
            }
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleNewSign(newSign, confidence: cameraManager.currentConfidence)
        }
        .task(id: temanTuliText) {
            guard !temanTuliText.isEmpty,
                  temanTuliText != lastAutoPlayedTemanTuliText
            else { return }

            appStore.signPredictionOutput = temanTuliText
            lastAutoPlayedTemanTuliText = temanTuliText
            await speakTemanTuliTranscription()
        }
    }

    // MARK: - Session Toolbar

    private var sessionToolbar: some View {
        HStack {
            if let session = appStore.activeSession {
                // Active session indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("session.active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("\(session.messageCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: .capsule)

                Button(role: .destructive) {
                    appStore.endSession()
                } label: {
                    Text("session.end")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    // If there's existing conversation data, confirm first
                    if !appStore.signPredictionOutput.isEmpty || !(speechStore?.transcribedText.isEmpty ?? true) {
                        showNewSessionAlert = true
                    } else {
                        appStore.startSession()
                    }
                } label: {
                    Label("session.start", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .alert("session.start_new_title", isPresented: $showNewSessionAlert) {
            Button("session.start_new_confirm") {
                appStore.startSession()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("session.start_new_desc")
        }
    }

    // MARK: - Conversation Section (Bubble Layout)

    private var conversationSection: some View {
        VStack(spacing: 8) {
            if !sessionMessages.isEmpty {
                ForEach(sessionMessages) { message in
                    MessageBubbleView(
                        content: message.content,
                        role: message.role,
                        timestamp: message.createdAt
                    )
                }
            }

            // Real-time transcription bubbles
            MessageBubbleView(
                content: temanTuliText,
                role: .sign,
                timestamp: .now,
                isPending: isSignActive && !temanTuliText.isEmpty
            )

            // Speech-to-text real-time bubble (only show if caregiverTranscribedText has the *latest* not-yet-committed text)
            // We show a pending bubble for the current speech transcription
            if let transcribed = speechStore?.transcribedText, !transcribed.isEmpty {
                let alreadyCounted = sessionMessages.filter { $0.role == .speech }.count
                let isNewTranscription = alreadyCounted == 0 || !sessionMessages.contains { $0.content == transcribed }
                if isNewTranscription {
                    MessageBubbleView(
                        content: transcribed,
                        role: .speech,
                        timestamp: .now,
                        isPending: speechStore?.isRecording == true
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControlsBar: some View {
        HStack(spacing: 10) {
            // Camera Flip
            if cameraManager.permissionGranted {
                Button(action: { cameraManager.toggleCamera() }) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }

            Spacer()

            // Mic toggle
            if let speechStore {
                Button {
                    if speechStore.isRecording {
                        speechStore.stopRecording()
                    } else {
                        speechStore.startRecording()
                    }
                } label: {
                    Image(systemName: speechStore.isRecording ? "mic.circle.fill" : "mic.fill")
                        .font(.title2.weight(.semibold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.glassProminent)
                .tint(speechStore.isRecording ? .red : .blue)
                .accessibilityLabel(speechStore.isRecording ? "Turn off microphone" : "Turn on microphone")
            }

            // Reset
            Button {
                resetSignRecognition()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Reused from existing code (cameraPane, signRecognitionControls, etc.)
    // [Keep all the existing cameraPane, signRecognitionControls, wordSequenceRow, etc.
    //  exactly as they are — unchanged from the current file]
}
```

> **Note:** The existing `cameraPane`, `signRecognitionControls`, `wordSequenceRow`, `sentencePanel`, `topPredictionSummary`, and all helper methods (`handleNewSign`, `clearDetectedWords`, `resetSignRecognition`, `toggleSpeechRecording`, `speakTemanTuliTranscription`, etc.) remain identical to the current implementation. Only the `conversationSection`, `sessionToolbar`, and `bottomControlsBar` are new or restructured.

- [ ] **Step 2: Sort through the actual file content — keep existing views, add new sections.**

The actual edit is: add the session toolbar + update conversation section to use `MessageBubbleView`. The camera pane, sign controls, word chips, prediction rows all stay exactly the same.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: update UnifiedView with bubble chat layout and session toolbar

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 9: Update SpeechToTextStore to Use MessageRole

**Files:**
- Modify: `SignLanguageApp/Features/SpeechToText/SpeechToTextStore.swift`

**Interfaces:**
- Consumes: updated `AppStore.addToHistory(message:role:)` with `MessageRole`
- Produces: updated `stopRecording()` using `.speech` role

- [ ] **Step 1: Update the `stopRecording()` call**

The current code calls `appStore.addToHistory(message: finalText, role: .userSpoke)`. The `ConversationRole` enum is being removed (deleted with `Conversation.swift`). Change `.userSpoke` → `.speech`.

```swift
// In stopRecording(), change the addToHistory call:
appStore.addToHistory(message: finalText, role: .speech)
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "fix: update SpeechToTextStore to use MessageRole.speech

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 10: Update SignToSpeechStore and TwoWayConversationStore to Use MessageRole

**Files:**
- Modify: `SignLanguageApp/Features/SignToSpeech/SignToSpeechStore.swift`
- Modify: `SignLanguageApp/Features/Conversation/TwoWayConversationStore.swift`

- [ ] **Step 1: Fix `SignToSpeechStore.swift`**

Change `.userSigned` → `.sign`:

```swift
// In speakPrediction():
appStore.addToHistory(message: text, role: .sign)
```

- [ ] **Step 2: Fix `TwoWayConversationStore.swift`**

Change `.userSigned` → `.sign`:

```swift
// In transitionToTTSAndSpeak():
appStore.addToHistory(message: textToSpeak, role: .sign)
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "fix: update stores to use MessageRole enum

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 11: Add Localization Strings

**Files:**
- Modify: `SignLanguageApp/Core/Localization/Localizable.xcstrings` (or whichever variant exists)

- [ ] **Step 1: Add new localization keys**

Add these keys (both Indonesian and English):

```
"session.start" = "Mulai Sesi" / "Start Session"
"session.end" = "Akhiri Sesi" / "End Session"
"session.active" = "Sesi Aktif" / "Active Session"
"session.start_new_title" = "Mulai Sesi Baru?" / "Start New Session?"
"session.start_new_confirm" = "Mulai" / "Start"
"session.start_new_desc" = "Memulai sesi baru akan menghapus transkripsi saat ini." / "Starting a new session will clear current transcription."
"history.session_untitled" = "Sesi tanpa judul" / "Untitled Session"
"history.session_active" = "Aktif" / "Active"
"history.detail_title" = "Detail Sesi" / "Session Detail"
"history.resume" = "Lanjutkan Percakapan" / "Resume Conversation"
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add session-related localization strings

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 12: Build & Verify

**Files:** None — this is a verification task.

- [ ] **Step 1: Build the project**

```bash
xcodebuild -project SignLanguageApp.xcodeproj -scheme SignLanguageApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any build errors**

If there are compilation errors, fix them iteratively until build succeeds.

- [ ] **Step 3: Make final commit with any fixes**

```bash
git add -A && git commit -m "fix: resolve build errors from session history refactor

Co-Authored-By: Claude <noreply@anthropic.com>"
```
