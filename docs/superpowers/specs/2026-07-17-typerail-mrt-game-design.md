# TypeRail — MRT Jakarta Typing Simulation Game

**Design doc** — 2026-07-17

---

## 1. Overview

TypeRail adalah game simulasi perjalanan MRT berbasis _typing_ yang memanfaatkan **MapKit** sebagai core framework dan **Core Haptics** sebagai supporting framework untuk menghadirkan pengalaman bermain native di ekosistem Apple. Pemain berperan sebagai operator MRT yang mengantarkan kereta melewati 13 stasiun MRT Jakarta Fase 1 (Lebak Bulus → Bundaran HI).

### Tech Stack

| Layer | Teknologi |
|-------|-----------|
| UI | SwiftUI 26.0+ |
| Map | MapKit for SwiftUI (`Map`, `MapPolyline`, `MapCamera`, `LookAroundPreview`) |
| Haptic | Core Haptics (`CHHapticEngine`, inline `CHHapticEvent` patterns) |
| Persistence | SwiftData (`@Model` for TripRecord) |
| State | `@Observable` stores + `actor` isolation for hardware services |
| Concurrency | Swift async/await, AsyncStream |

---

## 2. Architecture (Pendekatan 1: MVVM + Observable Stores + Actor Services)

### Folder Structure

```
TypeRail/TypeRailApp/
├── App/
│   └── TypeRailApp.swift                 # @main entry
├── Core/
│   ├── Haptics/
│   │   └── HapticEngine.swift            # CHHapticEngine actor wrapper
│   ├── Map/
│   │   └── MapController.swift           # Coordinator untuk MapKit rendering
│   ├── Logging/
│   │   └── AppLogger.swift               # os.Logger wrapper
│   └── Persistence/
│       └── GamePersistence.swift         # SwiftData CRUD
├── Models/
│   ├── MRTStation.swift                  # Data stasiun MRT Jakarta
│   ├── MRTRoute.swift                    # Polyline + rute keseluruhan
│   ├── GameState.swift                   # State machine enum
│   └── TripRecord.swift                  # Riwayat perjalanan (SwiftData @Model)
├── Services/
│   ├── RouteService.swift                # Data provider MRT Jakarta
│   ├── TypingEngine.swift                # Typing logic + scoring
│   ├── TrainAnimationService.swift       # Animasi kereta di polyline
│   ├── CameraService.swift               # Camera heading + zoom adaptif
│   └── HapticPatterns.swift              # Factory untuk AHAP patterns
├── Features/
│   ├── Game/
│   │   ├── GameStore.swift               # @Observable central state
│   │   └── GameScreen.swift              # Map + typing UI
│   ├── Arrival/
│   │   └── ArrivalScreen.swift           # LookAround + discovery
│   ├── History/
│   │   └── HistoryView.swift             # Trip records list
│   ├── Settings/
│   │   └── SettingsView.swift            # Reset + about
│   └── Content/
│       └── RootView.swift                # Navigation entry
└── Resources/
    └── Assets.xcassets/
```

### Data Flow Diagram

```
User Input (Keyboard via TextField)
       │
       ▼
TypingEngine ──(accuracy, speed, combo)──> GameStore (@Observable)
       ▲                                        │
       │                                        ├──> MapController (update camera, polyline position)
       │                                        ├──> HapticEngine (play context-sensitive pattern)
       │                                        └──> GamePersistence (save TripRecord)
       │
GameStore ──(currentStation, speed, score, combo, errorCount, gamePhase)
       │
       ▼
GameScreen / ArrivalScreen (SwiftUI views)
```

### State Machine

```
IDLE ──(start)──> TRAVELING ──(arrive)──> DOCKED ──(next)──> TRAVELING
                      │                      │                    │
                  (typo)                (lookAround)         (last station)
                      ▼                      ▼                    ▼
                   SLOWED               EXPLORING              FINISHED
```

---

## 3. MRT Jakarta Fase 1 (13 Stations)

```
Index  Station Name        Coordinate (approx)
─────────────────────────────────────────────────────
0      Lebak Bulus         -6.3100, 106.7800
1      Fatmawati           -6.2900, 106.7900
2      Cipete Raya         -6.2780, 106.7980
3      Haji Nawi           -6.2660, 106.8050
4      Blok A              -6.2520, 106.8100
5      Blok M              -6.2440, 106.7980
6      ASEAN               -6.2380, 106.7900
7      Senayan             -6.2250, 106.7960
8      Istora              -6.2150, 106.8080
9      Bendungan Hilir     -6.2080, 106.8180
10     Setiabudi           -6.2010, 106.8280
11     Dukuh Atas          -6.1940, 106.8350
12     Bundaran HI         -6.1850, 106.8180
```

Polyline disusun dari coordinate tersebut dengan waypoint interpolasi untuk mengikuti trace jalur MRT yang sebenarnya.

---

## 4. Typing Mechanics & Scoring

### Mekanisme
- **Target:** Nama stasiun tujuan (contoh: "Bundaran HI", "Fatmawati")
- **Input:** SwiftUI `TextField` dengan `.onKeyPress` untuk real-time feedback
- **Validasi:** Per karakter, per kata selesai
- **Akurasi:** `count(correctChars) / count(totalChars) × 100`
- **Kecepatan (WPM):** `(totalChars / 5) / (elapsedTime / 60)`

### Scoring

| Event | Points |
|-------|--------|
| Perfect accuracy (100%) per stasiun | +100 × combo multiplier |
| Partial (1-2 typo) | +50 × combo multiplier |
| Typo | -10, reset combo |
| Arrive on time | +50 bonus |
| Typo cooldown (anti-spam 300ms) | — |

### Combo System
- Combo+1 per stasiun tanpa error
- Multiplier: 1.0 → 1.5 → 2.0 → 2.5 → 3.0 → 3.5 → 4.0 → 4.5 → 5.0 (cap ×5)
- Reset ke 0 saat typo
- Notifikasi haptic di milestone ×3 dan ×5

---

## 5. Core Haptics Implementation

### Device Check
```swift
let hapticCapability = CHHapticEngine.capabilitiesForHardware()
supportsHaptics = hapticCapability.supportsHaptics
```
Fallback: visual flash + audio beep untuk iPad/non-haptic devices.

### Haptic Engine (Actor)
```swift
actor HapticEngine {
    private var engine: CHHapticEngine?
    private var speedPlayer: CHHapticAdvancedPatternPlayer?
    // ... resetHandler, stoppedHandler, start(), playPattern(), updateSpeed()
}
```

### Pattern Map (all generated inline via CHHapticEvent dictionaries)

| Kondisi | Intensitas | Sharpness | Tipe |
|---------|-----------|-----------|------|
| Start acceleration | 0.6 | 0.8 | Transient |
| Cruising (medium) | 0.3 | 0.2 | Continuous (dynamic) |
| High speed | 0.6 → 0.8 | 0.5 → 0.7 | Continuous (dynamic) |
| Entering turn | 0.4→0.7 sweep | 0.3→0.8 sweep | Multiple transient |
| Entering tunnel | 0.3 | 0.1 (dampened) | Continuous |
| Exiting tunnel | 0.3 → 0.7 ramp | 0.1 → 0.6 ramp | Ramp |
| Arriving station | 0.6→0.3→0.1 | 0.7→0.5→0.3 | 3× decrescendo transient |
| Doors open | 0.5 | 0.9 | 2× sharp tap |
| Doors close | 0.7 buzz, 0.5 tap | 0.5, 0.9 | Buzz + sharp |
| Correct char type | 0.2 | 0.3 | Light transient |
| Wrong char type | 0.4 | 0.1 | Buzz transient |
| Combo ×3 / ×5 | 0.8 | 0.9 | Rapid burst |
| Perfect accuracy | 0.5→0.9 ascending | 0.5→0.9 ascending | Multiple ascending |

---

## 6. MapKit Implementation

### Features

| Feature | Implementation |
|---------|---------------|
| Route polyline | `MapPolyline` dari CLLocationCoordinate2D array |
| Train annotation | Custom `Annotation` dengan `"tram.fill"` SF Symbol |
| Station markers | `Marker` with color state: visited (gray), current (blue), upcoming (green) |
| Camera tracking | `MapCamera(centerCoordinate:distance:heading:pitch:)` update per frame |
| Dynamic heading | `bearing(from:to:)` computed per polyline segment |
| Dynamic zoom | distance = 800m → 200m (high speed → zoom out, low speed → zoom in) |
| Dynamic pitch | 45° (lurus) → 75° (tikungan) → 90° (terowongan) |
| Look Around | `LookAroundPreview` dan `.lookAroundViewer()` saat DOCKED |

### Camera Transition Rules

```
Traveling:
  centerCoordinate = trainPosition (lerped along polyline)
  heading = bearing(currentStation, nextStation)
  distance = base(500m) - (speedRatio × 300m)  // clamp [200, 800]
  pitch:
    - sharp turn (>30° bearing delta) → 75°
    - tunnel proximity → 90° (top-down)
    - high speed (>80%) → 45°
    - arriving (>90% progress) → 30°, distance → 200m
    - default → 60°
```

### Train Animation
- `MKMapPoint` linear interpolation antara source dan destination station
- `progress` = elapsedTime / totalTripDuration
- `progress` affected by typing: correct char → progress +smallDelta; typo → progress -penalty
- Update via GameStore timer loop (~30fps cukup untuk pergerakan smooth)

---

## 7. UI/UX

### Game Screen Layout (portrait)

```
┌──────────────────────────────┐
│         Status HUD           │  ← Score, Speed, Combo, Station (X/13)
├──────────────────────────────┤
│                              │
│        MapKit Map            │  ← ~60% screen
│   (polyline, train anim,    │
│    station markers)          │
│                              │
├──────────────────────────────┤
│  🚃 Lebak Bulus → Fatmawati   │
│  ┌────────────────────────┐ │
│  │  Fatmawati              │ │  ← Typing TextField
│  └────────────────────────┘  │
│  [████████░░] 73% accuracy   │
│  ⌨️ [Fat] (suggestion)      │
└──────────────────────────────┘
```

### Arrival Screen (DOCKED)

```
┌──────────────────────────────┐
│  ✅ Tiba di Fatmawati!       │
│  00:45 · 100% · +150 pts    │
├──────────────────────────────┤
│                              │
│   LookAroundPreview          │  ← street-level preview
│                              │
├──────────────────────────────┤
│  [🔍 Explore] [🚃 Lanjut]    │
│  [⏹ Akhiri]                 │
└──────────────────────────────┘
```

### Screen States
- **IDLE:** Map centered Lebak Bulus, "Mulai Perjalanan" CTA
- **TRAVELING:** Game Screen with typing field + HUD
- **SLOWED:** Red flash indicator, speed bar depletion, haptic buzz
- **DOCKED:** Arrival Screen with LookAround
- **EXPLORING:** Full LookAround viewer
- **FINISHED:** Trip summary + review stats

---

## 8. Persistence (SwiftData)

### TripRecord (`@Model`)

```swift
@Model
final class TripRecord {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var stationsCompleted: Int       // 0-13
    var totalScore: Int
    var averageAccuracy: Double
    var topCombo: Int
    var totalErrors: Int
}
```

### Operations
- `save(_:)` — save completed trip
- `loadAll()` — fetch history
- `deleteAll()` — reset all data
- Preferences (first-launch flag, etc): `UserDefaults`

---

## 9. Error Handling & Edge Cases

| Skenario | Penanganan |
|----------|-----------|
| No haptic support (iPad) | Visual + audio fallback |
| Map load failure | Retry → static coordinate fallback |
| Empty typing field | Disabled submit, placeholder text |
| Anti-spam typing | 300ms cooldown antar character |
| App backgrounded | Auto-pause via `scenePhase`, save state |
| Phone call interruption | HapticEngine stoppedHandler → pause, resume on foreground |
| Last station arrival | Special celebration flow → FINISHED |
| Data reset | SwiftData `modelContext.delete(model)` + UserDefaults clear |

---

## 10. Testing Strategy

### Unit Tests (Swift Testing)

| Component | Test Cases |
|-----------|-----------|
| **TypingEngine** | Accuracy calculation, WPM, combo multiplier, score aggregation |
| **GameState** | State transition validity (idle→traveling→docked, d→f→idle invalid transitions) |
| **CameraService** | Bearing calculation, distance clamping, pitch rules |
| **HapticPatterns** | Pattern creation (no throw), parameter ranges |

### Integration Tests
| Component | Test Cases |
|-----------|-----------|
| **GameStore** | Full trip simulation (state machine, typing → scoring → persistence) |
| **GamePersistence** | CRUD operations, reset, empty state |

### UI Tests (future)
- Typing interaction, button taps
- Map interaction (pinch, pan — non-functional requirement)

---

## 11. Future Possibilities

| Feature | Path |
|---------|------|
| **Level/challenge mode** | Tambah GameMode enum, filter stations, Timer constraint |
| **Multiplayer/Leaderboard** | GameCenter GKLeaderboard, GKMatchManager |
| **Additional MRT lines** | RouteService → protocol-based, add Fase 2/3 data |
| **Sound effects** | PHASE framework integration alongside haptics |
| **AR Mode** | ARKit + MapKit annotation di dunia nyata |

---

## 12. Design Decisions

| Keputusan | Alasan |
|-----------|--------|
| SwiftData over CoreData | Modern, Swift-native, async-first, minimal boilerplate |
| Inline CHHapticEvent over AHAP file | No file I/O, dynamic parameter control lebih mudah |
| Observable + actor over Combine | Sejalan dengan Airbnb Swift style, async/await native |
| Standard MapCamera over custom MKMapView subclass | Cukup powerful, minimal maintenance |
| Typing field over custom gesture recognizer | Keyboard support built-in, aksesibilitas |
