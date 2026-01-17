# MVVM vs TCA Comparison

## Executive Summary

For SergeantMusic Phase 1, we recommend **MVVM + Coordinators** over The Composable Architecture (TCA). This decision is based on the user's new-to-iOS status and the fact that audio/MIDI threading concerns are orthogonal to UI architecture choice.

**Migration Path:** TCA remains an option for Phase 2+ if state complexity warrants.

## Architecture Pattern Comparison

### MVVM (Model-View-ViewModel)

**What it is:**
- Standard iOS architecture pattern
- Uses SwiftUI's `ObservableObject` and `@Published` properties
- ViewModels transform data for UI consumption
- Coordinator pattern handles navigation

**Strengths:**
- ✅ Low learning curve - standard iOS pattern
- ✅ Vast ecosystem and resources
- ✅ Fast initial development
- ✅ Works seamlessly with SwiftUI
- ✅ Easy debugging with standard Xcode tools
- ✅ Flexible - no framework constraints

**Weaknesses:**
- ❌ State can become unpredictable in complex scenarios
- ❌ Requires discipline for testability
- ❌ No built-in effect handling
- ❌ Manual coordination between ViewModels

### TCA (The Composable Architecture)

**What it is:**
- Functional architecture by Point-Free
- Unidirectional data flow
- All state changes via Reducers
- Side effects handled via Effects
- Built-in testing support

**Strengths:**
- ✅ Predictable state flow
- ✅ Excellent testability
- ✅ Built-in effect handling
- ✅ Time-travel debugging
- ✅ Composable components

**Weaknesses:**
- ❌ Steep learning curve
- ❌ High boilerplate
- ❌ Framework lock-in
- ❌ Smaller ecosystem
- ❌ Slower initial development

## Decision Matrix

| Factor | MVVM | TCA | Winner |
|--------|------|-----|--------|
| **Learning Curve** | Low - standard iOS | High - new concepts | MVVM |
| **Initial Velocity** | Fast prototyping | Slower due to boilerplate | MVVM |
| **State Predictability** | Manual discipline needed | Built-in via Reducer | TCA |
| **Testability** | Good with effort | Excellent by default | TCA |
| **Audio Thread Safety** | Manual (same as TCA) | Manual (same as MVVM) | Tie |
| **Community Support** | Massive | Growing but niche | MVVM |
| **Debugging** | Standard Xcode tools | Specialized tools | MVVM |
| **Flexibility** | High - no framework | Framework constraints | MVVM |
| **New Developer** | Easy to understand | Requires training | MVVM |
| **Migration Risk** | Easy to refactor | Hard to escape | MVVM |

## The Audio/MIDI Reality Check

**Critical Insight:** Neither MVVM nor TCA solves real-time audio challenges.

### Why Audio Is Different

Real-time audio has unique constraints that exist **outside** any UI architecture:

1. **Audio Render Thread**
   - Runs at highest priority
   - MUST be lock-free (no allocations, no locks)
   - Cannot use `@Published` (MVVM) or `Store.send` (TCA)
   - Requires lock-free ring buffer regardless of architecture

2. **MIDI Callback Thread**
   - Core MIDI runs on its own thread
   - Must dispatch to audio thread quickly
   - Cannot directly update UI state

3. **UI Updates**
   - Must happen on main thread
   - Audio events queue up via lock-free buffer
   - 60 Hz polling retrieves events
   - This pattern is identical in both architectures

### Audio Architecture (Same for Both)

```
Audio Render Thread (lock-free)
    ↓
Lock-Free Ring Buffer
    ↓
Main Thread Timer (60 Hz)
    ↓
[MVVM: Update @Published]  OR  [TCA: Store.send(action)]
    ↓
SwiftUI Re-renders
```

**The audio subsystem is the same regardless of MVVM vs TCA.**

## Recommendation: MVVM for Phase 1

### Rationale

1. **User Is New to iOS**
   - Learning SwiftUI + AVAudioEngine + Core MIDI is already substantial
   - Adding TCA would be overwhelming
   - MVVM is the standard approach taught in Apple documentation

2. **Audio Is the Hard Part**
   - Threading complexity is architecture-agnostic
   - Both require the same lock-free patterns
   - Focus effort on getting audio right, not UI architecture

3. **Fast Validation**
   - MVP should validate musical concepts
   - MVVM allows faster iteration
   - Can get to working prototype sooner

4. **Clear Migration Path**
   - MVVM → TCA migration is well-documented
   - Can reassess after MVP
   - Many apps successfully use MVVM for complex state

5. **Better Debugging**
   - Audio bugs are subtle and timing-dependent
   - Standard Xcode debugging works better with MVVM
   - TCA's indirection adds debugging complexity

### When to Reconsider TCA

**Phase 2+** - Consider TCA if:
- State coordination becomes painful
- Testing is difficult
- Multiple ViewModels stepping on each other
- Complex async workflows hard to reason about

**Signs You Need TCA:**
- Frequent state synchronization bugs
- Difficulty testing UI logic
- ViewModels becoming massive
- Race conditions in state updates

## MVVM Implementation Strategy

### Architecture Pattern

```mermaid
flowchart TB
    Views[SwiftUI Views<br/>PracticeView, FretboardView, etc.]
    VMs[ViewModels<br/>@Published state, ObservableObject]
    Coord[PracticeCoordinator<br/>Orchestrates Audio + MIDI + UI]
    Audio[Audio Subsystem]
    MIDI[MIDI Subsystem]

    Views -->|Binding| VMs
    VMs -->|Delegates| Coord
    Coord --> Audio
    Coord --> MIDI
```

### Key Patterns

#### 1. ViewModels as Data Transformers

```swift
@MainActor
class PracticeViewModel: ObservableObject {
    // UI state
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Int = 0
    @Published var currentChord: Chord?
    @Published var tempo: Double = 120

    // Dependencies
    private let coordinator: PracticeCoordinator

    // Transform audio events to UI state
    func handleAudioEvent(_ event: AudioEvent) {
        switch event {
        case .beatChanged(let beat):
            currentBeat = beat
        case .chordChanged(let chord):
            currentChord = chord
        }
    }

    // User actions delegate to coordinator
    func play() {
        coordinator.play()
        isPlaying = true
    }
}
```

#### 2. PracticeCoordinator as Bridge

```swift
class PracticeCoordinator {
    // Audio subsystem (audio thread)
    private let audioEngine: AudioEngineManager
    private let sequencer: EventSequencer

    // MIDI subsystem
    private let midiManager: MIDIManager

    // Lock-free bridge
    private let audioEventQueue = AudioThreadSafeQueue<AudioEvent>()

    // ViewModels observe this coordinator
    private var updateTimer: AnyCancellable?

    // Audio thread → Main thread
    func startUIUpdateLoop() {
        updateTimer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processAudioEvents()
            }
    }

    private func processAudioEvents() {
        let events = audioEventQueue.dequeueAll()
        // Notify ViewModels
        events.forEach { event in
            notifyViewModels(event)
        }
    }
}
```

#### 3. Lock-Free Audio Communication

```swift
// Audio thread writes (no locks!)
func audioRenderCallback() {
    // Process audio...

    // Notify UI (lock-free)
    audioEventQueue.enqueue(.beatChanged(currentBeat))
}

// Main thread reads (60 Hz)
func processAudioEvents() {
    let events = audioEventQueue.dequeueAll()
    events.forEach { viewModel.handleAudioEvent($0) }
}
```

### Testing Strategy

```swift
// ViewModels are easily testable
class PracticeViewModelTests: XCTestCase {
    func testBeatUpdate() {
        let viewModel = PracticeViewModel(coordinator: mockCoordinator)

        // Simulate audio event
        viewModel.handleAudioEvent(.beatChanged(42))

        // Assert UI state
        XCTAssertEqual(viewModel.currentBeat, 42)
    }
}

// Coordinator tests with mock audio engine
class PracticeCoordinatorTests: XCTestCase {
    func testPlay() {
        let mockAudio = MockAudioEngine()
        let coordinator = PracticeCoordinator(audioEngine: mockAudio)

        coordinator.play()

        XCTAssertTrue(mockAudio.isPlaying)
    }
}
```

## TCA Alternative (For Reference)

If you were to use TCA, here's how it would look:

```swift
struct PracticeState: Equatable {
    var isPlaying: Bool = false
    var currentBeat: Int = 0
    var currentChord: Chord?
    var tempo: Double = 120
}

enum PracticeAction: Equatable {
    case playTapped
    case audioEventReceived(AudioEvent)
    case tempoChanged(Double)
}

struct PracticeEnvironment {
    var audioEngine: AudioEngineClient
    var midiManager: MIDIManagerClient
}

let practiceReducer = Reducer<PracticeState, PracticeAction, PracticeEnvironment> {
    state, action, environment in

    switch action {
    case .playTapped:
        state.isPlaying = true
        return environment.audioEngine.play()
            .fireAndForget()

    case .audioEventReceived(.beatChanged(let beat)):
        state.currentBeat = beat
        return .none

    case .tempoChanged(let tempo):
        state.tempo = tempo
        return environment.audioEngine.setTempo(tempo)
            .fireAndForget()
    }
}
```

**Note:** Audio thread communication is still lock-free ring buffer in TCA. The reducer runs on main thread, not audio thread.

## Migration Path: MVVM → TCA

If state management becomes problematic in Phase 2, migration is straightforward:

### Step 1: Identify State
Extract @Published properties into a State struct.

### Step 2: Identify Actions
Convert user actions and events into Action enum.

### Step 3: Create Reducer
Move logic from ViewModel methods into reducer.

### Step 4: Keep Audio Layer Unchanged
Audio subsystem doesn't change - still uses lock-free queue.

### Step 5: Gradual Migration
Migrate feature-by-feature, not all at once.

## Real-World Examples

### Apps Using MVVM Successfully
- Instagram
- Spotify
- Netflix iOS app
- Most iOS apps with complex state

### Apps Using TCA
- isowords (Point-Free's game)
- Some financial apps
- Growing adoption in 2025-2026

### Audio Apps Pattern
- **GarageBand:** Custom architecture (likely not TCA or pure MVVM)
- **AUM:** MVVM-like with audio engine
- **Most DAWs:** Audio layer separate from UI architecture

**Key Takeaway:** Audio apps focus on audio engine correctness, not UI architecture pattern.

## Decision

**For Phase 1: Use MVVM + Coordinators**

### Implementation Plan
1. **Week 1-2:** Build audio subsystem (architecture-agnostic)
2. **Week 2-3:** Add MVVM ViewModels for UI
3. **Week 3-4:** Polish, test, validate MVP
4. **Phase 2:** Reassess based on actual pain points

### Success Criteria
- Audio latency < 20ms ✓
- MIDI jitter < 5ms ✓
- UI responsive 60 FPS ✓
- Development velocity high ✓
- Codebase maintainable ✓

### Reassessment Triggers
- State bugs become frequent
- Testing is painful
- ViewModels exceed 300 lines
- Coordination logic becomes tangled

---

## Conclusion

MVVM is the pragmatic choice for Phase 1 given:
1. User's new-to-iOS status
2. Audio threading is architecture-agnostic
3. Fast validation of musical concepts is priority
4. Clear migration path exists if needed

**The audio engine doesn't care about MVVM vs TCA - focus effort there.**

---

**Related Documents:**
- [Architecture Overview](architecture-overview.md)
- [Audio Architecture](audio-architecture.md)
- [State Management](state-management.md)
- [ADR-001: MVVM for Phase 1](../adr/ADR-001-mvvm-for-phase-1.md)
