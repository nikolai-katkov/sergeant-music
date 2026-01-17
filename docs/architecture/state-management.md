# State Management

## Overview

This document describes how SergeantMusic manages application state across the audio subsystem, MIDI subsystem, and UI layer. The architecture uses MVVM with a central PracticeCoordinator to bridge between real-time audio threads and the main UI thread.

## State Management Challenges

SergeantMusic has unique state management challenges:

1. **Multi-threaded State:** Audio thread, MIDI thread, main thread all need access to state
2. **Real-Time Constraints:** Audio thread cannot use locks or allocations
3. **Timing Precision:** State updates must be sample-accurate for visualization
4. **State Synchronization:** UI must reflect audio state with < 50ms latency
5. **Complex State:** Exercise data, playback position, MIDI config, user preferences

## Architecture Pattern: MVVM + Coordinator

### Why MVVM?

- **Familiar:** Standard iOS pattern, extensive resources
- **SwiftUI Integration:** ObservableObject and @Published work seamlessly
- **Testable:** ViewModels easily unit tested
- **Flexible:** No framework constraints

### Why Coordinator?

- **Centralized Logic:** Single source for cross-subsystem coordination
- **Thread Safety:** Handles thread boundaries explicitly
- **Separation of Concerns:** ViewModels focus on UI, Coordinator handles audio/MIDI

## State Flow Architecture

```mermaid
flowchart TB
    subgraph Main["Main Thread (UI)"]
        Views[SwiftUI Views<br/>Bind to @Published<br/>Trigger user actions]

        VMs[ViewModels<br/>ObservableObject<br/>@Published isPlaying<br/>@Published currentBeat<br/>@Published currentChord]

        Coord[PracticeCoordinator<br/>Bridges audio + MIDI + UI<br/>Manages lock-free queue<br/>Dispatches to audio queue]

        Views -->|Binding| VMs
        VMs -->|Delegate/Callback| Coord
    end

    Coord --> Audio[Audio Subsystem<br/>Audio Thread]
    Coord --> MIDI[MIDI Subsystem<br/>MIDI Thread]
```

## Core State Types

### 1. Playback State

**Owned by:** Audio subsystem (EventSequencer)
**Published to:** UI via PracticeCoordinator

```swift
struct PlaybackState {
    var isPlaying: Bool
    var currentBeat: Double
    var currentBar: Int
    var tempo: Double
    var timeSignature: TimeSignature
    var currentChord: Chord?
    var loopRegion: LoopRegion?
}
```

### 2. Exercise State

**Owned by:** ExerciseService
**Published to:** UI via ViewModels

```swift
struct Exercise: Codable {
    let id: String
    let title: String
    let key: String
    let tempo: Double
    let timeSignature: String
    let grooveStyle: String
    let chords: [ChordEvent]
    let melody: [NoteEvent]
    let metadata: ExerciseMetadata
}

struct ExerciseMetadata: Codable {
    let difficulty: Difficulty
    let category: String
    let duration: Double
    let allowedViews: [VisualizationMode]
}
```

### 3. MIDI Configuration State

**Owned by:** MIDIManager
**Published to:** UI via SettingsViewModel

```swift
struct MIDIConfiguration {
    var connectedDevices: [MIDIDevice]
    var activeDevice: MIDIDevice?
    var mappings: [MIDIMapping]
    var isEnabled: Bool
}
```

### 4. Visualization State

**Owned by:** Individual ViewModels
**Derived from:** PlaybackState

```swift
struct FretboardState {
    var visibleNotes: [FretboardNote]
    var highlightedNotes: [FretboardNote]
    var theoryOverlay: TheoryOverlayMode
    var upcomingNotes: [FretboardNote] // Lookahead
}

struct NotationState {
    var cursorPosition: Double // Beat position
    var visibleRange: ClosedRange<Double> // Visible beats
    var notes: [NoteEvent]
    var scrollOffset: CGFloat
}
```

## PracticeCoordinator: The Central Hub

**Responsibility:** Coordinate audio, MIDI, and UI subsystems.

**File:** `/Services/PracticeCoordinator.swift`

```swift
@MainActor
class PracticeCoordinator: ObservableObject {
    // Published state for ViewModels
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentBeat: Int = 0
    @Published private(set) var currentChord: Chord?
    @Published private(set) var tempo: Double = 120
    @Published private(set) var currentExercise: Exercise?

    // Subsystems
    private let audioEngine: AudioEngineManager
    private let sequencer: EventSequencer
    private let midiManager: MIDIManager
    private let exerciseService: ExerciseService

    // Thread communication
    private let audioEventQueue = AudioThreadSafeQueue<AudioEvent>()
    private let audioQueue = DispatchQueue(label: "com.sergeantmusic.audio", qos: .userInteractive)
    private var updateTimer: AnyCancellable?

    // ViewModels
    weak var practiceViewModel: PracticeViewModel?
    weak var fretboardViewModel: FretboardViewModel?
    weak var notationViewModel: NotationViewModel?

    init(audioEngine: AudioEngineManager,
         sequencer: EventSequencer,
         midiManager: MIDIManager,
         exerciseService: ExerciseService) {
        self.audioEngine = audioEngine
        self.sequencer = sequencer
        self.midiManager = midiManager
        self.exerciseService = exerciseService

        setupAudioEventFlow()
    }

    // MARK: - Audio Event Flow

    private func setupAudioEventFlow() {
        // Audio thread → Main thread pipeline
        sequencer.onEvent = { [weak self] event in
            self?.audioEventQueue.enqueue(event)
        }

        // Main thread polling (60 Hz)
        startUIUpdateLoop()
    }

    private func startUIUpdateLoop() {
        updateTimer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processAudioEvents()
            }
    }

    @MainActor
    private func processAudioEvents() {
        let events = audioEventQueue.dequeueAll()

        for event in events {
            switch event {
            case .beatChanged(let beat):
                currentBeat = Int(beat)
                practiceViewModel?.update(beat: beat)
                fretboardViewModel?.update(beat: beat)
                notationViewModel?.update(beat: beat)

            case .chordChanged(let chord):
                currentChord = chord
                practiceViewModel?.update(chord: chord)
                fretboardViewModel?.update(chord: chord)

            case .playbackStateChanged(let playing):
                isPlaying = playing
                practiceViewModel?.update(isPlaying: playing)

            case .loopCompleted:
                // Handle loop completion
                break
            }
        }
    }

    // MARK: - User Actions (UI → Audio)

    func loadExercise(_ exercise: Exercise) {
        currentExercise = exercise
        tempo = exercise.tempo

        audioQueue.async { [weak self] in
            self?.sequencer.loadExercise(exercise)
            self?.audioEngine.backingTrackEngine.loadExercise(exercise)
        }
    }

    func play() {
        audioQueue.async { [weak self] in
            self?.sequencer.start()
        }
    }

    func pause() {
        audioQueue.async { [weak self] in
            self?.sequencer.stop()
        }
    }

    func setTempo(_ newTempo: Double) {
        tempo = newTempo

        audioQueue.async { [weak self] in
            self?.sequencer.setTempo(newTempo)
        }
    }

    func setLoopRegion(start: Int, end: Int) {
        audioQueue.async { [weak self] in
            self?.sequencer.setLoopRegion(startBar: start, endBar: end)
        }
    }

    func skipToBar(_ bar: Int) {
        audioQueue.async { [weak self] in
            self?.sequencer.skipToBar(bar)
        }
    }
}
```

## ViewModel Pattern

### PracticeViewModel

**Responsibility:** Manage practice session UI state.

**File:** `/Features/Practice/ViewModels/PracticeViewModel.swift`

```swift
@MainActor
class PracticeViewModel: ObservableObject {
    // UI state
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Int = 0
    @Published var currentBar: Int = 0
    @Published var currentChord: Chord?
    @Published var tempo: Double = 120
    @Published var exercise: Exercise?

    // Dependencies
    private let coordinator: PracticeCoordinator

    init(coordinator: PracticeCoordinator) {
        self.coordinator = coordinator
        self.coordinator.practiceViewModel = self
    }

    // MARK: - User Actions

    func playTapped() {
        if isPlaying {
            coordinator.pause()
        } else {
            coordinator.play()
        }
    }

    func tempoChanged(_ newTempo: Double) {
        tempo = newTempo
        coordinator.setTempo(newTempo)
    }

    func loadExercise(_ exercise: Exercise) {
        self.exercise = exercise
        coordinator.loadExercise(exercise)
    }

    // MARK: - State Updates from Coordinator

    func update(beat: Double) {
        currentBeat = Int(beat)
        currentBar = Int(beat / 4) // Assuming 4/4
    }

    func update(chord: Chord) {
        currentChord = chord
    }

    func update(isPlaying: Bool) {
        self.isPlaying = isPlaying
    }
}
```

### FretboardViewModel

**Responsibility:** Transform playback state to fretboard visualization.

**File:** `/Features/Fretboard/ViewModels/FretboardViewModel.swift`

```swift
@MainActor
class FretboardViewModel: ObservableObject {
    // Visualization state
    @Published var visibleNotes: [FretboardNote] = []
    @Published var highlightedNotes: [FretboardNote] = []
    @Published var theoryOverlay: TheoryOverlayMode = .intervals
    @Published var currentChord: Chord?

    // Dependencies
    private let coordinator: PracticeCoordinator
    private let fretboardLayout: FretboardLayout

    init(coordinator: PracticeCoordinator, layout: FretboardLayout) {
        self.coordinator = coordinator
        self.fretboardLayout = layout
        self.coordinator.fretboardViewModel = self
    }

    // MARK: - State Updates

    func update(chord: Chord) {
        currentChord = chord

        // Transform chord to fretboard notes
        visibleNotes = chord.notes.compactMap { note in
            fretboardLayout.position(for: note)
        }
    }

    func update(beat: Double) {
        // Update highlighted notes based on playback position
        if let exercise = coordinator.currentExercise {
            highlightedNotes = notesAt(beat: beat, in: exercise)
        }
    }

    private func notesAt(beat: Double, in exercise: Exercise) -> [FretboardNote] {
        // Find melody notes at current beat
        let currentNotes = exercise.melody.filter { noteEvent in
            beat >= noteEvent.startBeat && beat < noteEvent.startBeat + noteEvent.duration
        }

        return currentNotes.compactMap { noteEvent in
            fretboardLayout.position(for: noteEvent.note)
        }
    }

    // MARK: - User Actions

    func toggleTheoryOverlay() {
        theoryOverlay = theoryOverlay.next()
    }
}

enum TheoryOverlayMode {
    case hidden
    case noteNames
    case intervals
    case scaleDegrees

    func next() -> TheoryOverlayMode {
        switch self {
        case .hidden: return .noteNames
        case .noteNames: return .intervals
        case .intervals: return .scaleDegrees
        case .scaleDegrees: return .hidden
        }
    }
}
```

### NotationViewModel

**Responsibility:** Transform playback state to notation visualization.

**File:** `/Features/Notation/ViewModels/NotationViewModel.swift`

```swift
@MainActor
class NotationViewModel: ObservableObject {
    // Visualization state
    @Published var cursorPosition: Double = 0
    @Published var visibleRange: ClosedRange<Double> = 0...16
    @Published var scrollOffset: CGFloat = 0
    @Published var notes: [NoteEvent] = []

    // Dependencies
    private let coordinator: PracticeCoordinator
    private let playbackCursor: PlaybackCursor

    init(coordinator: PracticeCoordinator, cursor: PlaybackCursor) {
        self.coordinator = coordinator
        self.playbackCursor = cursor
        self.coordinator.notationViewModel = self
    }

    // MARK: - State Updates

    func update(beat: Double) {
        cursorPosition = beat

        // Update scroll position
        scrollOffset = playbackCursor.beatToScreenPosition(beat)

        // Update visible range (show 4 bars ahead, 2 bars behind)
        let lookBehind = 8.0
        let lookAhead = 16.0
        visibleRange = max(0, beat - lookBehind)...(beat + lookAhead)
    }

    func loadExercise(_ exercise: Exercise) {
        notes = exercise.melody
    }
}
```

## State Synchronization Patterns

### Pattern 1: Audio → UI (State Updates)

**Challenge:** Audio state changes on audio thread, UI needs updates on main thread.

**Solution:** Lock-free queue + 60 Hz polling

```swift
// Audio thread (lock-free)
func audioRenderCallback() {
    // Update state
    currentBeat += 1

    // Enqueue event (no locks!)
    audioEventQueue.enqueue(.beatChanged(currentBeat))
}

// Main thread (60 Hz)
func processAudioEvents() {
    let events = audioEventQueue.dequeueAll()

    events.forEach { event in
        // Update @Published properties
        switch event {
        case .beatChanged(let beat):
            currentBeat = Int(beat)
        }
    }
}
```

### Pattern 2: UI → Audio (Commands)

**Challenge:** User actions on main thread must trigger audio operations.

**Solution:** Audio queue dispatch

```swift
// Main thread
func playButton() {
    // Dispatch to audio queue
    audioQueue.async { [weak self] in
        self?.sequencer.start()
    }

    // Update UI state immediately (optimistic)
    isPlaying = true
}
```

### Pattern 3: Derived State

**Challenge:** Some state is derived from multiple sources.

**Solution:** Combine in ViewModel

```swift
class PracticeViewModel: ObservableObject {
    @Published var currentBeat: Int = 0
    @Published var tempo: Double = 120

    // Derived state
    var currentTime: TimeInterval {
        return Double(currentBeat) * (60.0 / tempo)
    }

    var currentBar: Int {
        return currentBeat / 4 // Assuming 4/4
    }
}
```

### Pattern 4: Lookahead State

**Challenge:** Visualization needs future events for smooth animation.

**Solution:** Lookahead calculation in ViewModel

```swift
class FretboardViewModel: ObservableObject {
    @Published var currentNotes: [FretboardNote] = []
    @Published var upcomingNotes: [FretboardNote] = [] // Next 2 beats

    func update(beat: Double) {
        let lookahead = 2.0 // beats

        // Current notes
        currentNotes = notesAt(beat: beat)

        // Upcoming notes
        upcomingNotes = notesInRange(beat...beat + lookahead)
    }
}
```

## Testing State Management

### Unit Tests

```swift
class PracticeViewModelTests: XCTestCase {
    func testBeatUpdate() {
        let mockCoordinator = MockPracticeCoordinator()
        let viewModel = PracticeViewModel(coordinator: mockCoordinator)

        // Simulate audio event
        viewModel.update(beat: 42.5)

        XCTAssertEqual(viewModel.currentBeat, 42)
        XCTAssertEqual(viewModel.currentBar, 10) // 42 / 4
    }

    func testTempoChange() {
        let mockCoordinator = MockPracticeCoordinator()
        let viewModel = PracticeViewModel(coordinator: mockCoordinator)

        viewModel.tempoChanged(140)

        XCTAssertEqual(viewModel.tempo, 140)
        XCTAssertTrue(mockCoordinator.setTempoCalled)
    }
}
```

### Integration Tests

```swift
class StateFlowTests: XCTestCase {
    func testAudioToUIFlow() {
        let coordinator = PracticeCoordinator(...)

        // Trigger audio event
        coordinator.audioEventQueue.enqueue(.beatChanged(10))

        // Wait for next UI update
        let expectation = XCTestExpectation(description: "UI updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            XCTAssertEqual(coordinator.currentBeat, 10)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
```

## State Persistence

### UserDefaults (Simple State)

```swift
class PreferencesService {
    @AppStorage("defaultTempo") var defaultTempo: Double = 120
    @AppStorage("defaultGroove") var defaultGroove: String = "rock-8th"
    @AppStorage("theoryOverlay") var theoryOverlay: String = "intervals"
}
```

### JSON Files (Complex State)

```swift
class ExerciseService {
    func loadExercise(_ id: String) throws -> Exercise {
        let url = Bundle.main.url(forResource: id, withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Exercise.self, from: data)
    }

    func saveExercise(_ exercise: Exercise) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("\(exercise.id).json")
        let data = try JSONEncoder().encode(exercise)
        try data.write(to: url)
    }
}
```

## State Management Best Practices

### 1. Single Source of Truth
- Audio subsystem owns playback state
- ExerciseService owns exercise data
- MIDIManager owns MIDI configuration
- ViewModels only hold UI-specific state

### 2. Unidirectional Data Flow
- Audio → Lock-free queue → Main thread → ViewModels → Views
- Never: Views → Audio (must go through coordinator)

### 3. Immutable Events
- Audio events are value types
- No shared mutable state between threads

### 4. Optimistic UI Updates
- Update UI immediately for user actions
- Confirm with audio events

### 5. Separation of Concerns
- ViewModels: UI state transformation
- Coordinator: Cross-subsystem coordination
- Services: Data persistence and loading

## Common Pitfalls & Solutions

### Pitfall 1: Updating @Published from Background Thread

```swift
// ❌ BAD
audioQueue.async {
    self.currentBeat = 42 // Crash! @Published is main-thread only
}

// ✅ GOOD
audioQueue.async {
    audioEventQueue.enqueue(.beatChanged(42))
}
// ... later on main thread ...
currentBeat = 42
```

### Pitfall 2: Calling Audio Operations on Main Thread

```swift
// ❌ BAD
func play() {
    sequencer.start() // Blocks main thread!
}

// ✅ GOOD
func play() {
    audioQueue.async {
        sequencer.start()
    }
}
```

### Pitfall 3: Shared Mutable State

```swift
// ❌ BAD
class SharedState {
    var currentBeat: Int = 0 // Data race!
}

// ✅ GOOD
// Audio thread owns, publishes via lock-free queue
// Main thread receives and updates @Published copy
```

## Next Steps

1. Implement PracticeCoordinator
2. Implement lock-free AudioThreadSafeQueue
3. Implement ViewModels (PracticeViewModel, FretboardViewModel, etc.)
4. Set up 60 Hz UI update loop
5. Test state flow with Thread Sanitizer
6. Add state persistence

---

**Related Documents:**
- [Architecture Overview](architecture-overview.md)
- [MVVM vs TCA Comparison](mvvm-vs-tca-comparison.md)
- [Audio Architecture](audio-architecture.md)
- [MIDI Architecture](midi-architecture.md)
