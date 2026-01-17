# Implementation Roadmap

## Overview

This document outlines the phased development approach for SergeantMusic, broken down by weeks with clear milestones and deliverables.

## Phase 1: MVP (Weeks 1-4)

### Week 1: Foundation & Audio Engine
**Goal:** Get basic audio playback working

**Tasks:**
- Xcode project setup with SPM dependencies (AudioKit, etc.)
- `AudioEngineManager` with AVAudioEngine lifecycle
- `AudioSessionManager` for iOS audio session configuration
- `MusicalClock` with tempo/beat tracking
- `MetronomeNode` playing click track
- Basic `PracticeView` with play/pause/tempo controls
- `PracticeViewModel` with @Published state

**Deliverable:** App that plays a metronome at adjustable tempo (40-240 BPM)

**Critical Files:**
- `/Audio/AudioEngine/AudioEngineManager.swift`
- `/Audio/AudioEngine/AudioSessionManager.swift`
- `/Audio/Sequencer/MusicalClock.swift`
- `/Audio/Synthesis/MetronomeNode.swift`
- `/Features/Practice/Views/PracticeView.swift`
- `/Features/Practice/ViewModels/PracticeViewModel.swift`

**Validation:**
- Metronome plays with clear click
- Tempo adjustable in real-time
- Audio continues in background
- No audio glitches

---

### Week 2: Backing Tracks + MIDI + Groove Library
**Goal:** Full backing track system with MIDI connectivity

**Tasks:**
- `BackingTrackEngine` coordinating multiple instruments
- `SamplePlayer` for drum sample playback (kick, snare, hi-hat, cymbals)
- Simple bass synthesis following chord roots
- **Implement 5-6 core groove patterns:**
  - Rock 8th note pattern
  - Rock 16th note pattern
  - Blues shuffle feel
  - Jazz swing pattern
  - Bossa nova rhythm
  - Pop/ballad straight feel
- `GroovePattern` model with drum/bass note sequences
- `MIDIManager` discovering and connecting to devices
- `MIDIDeviceScanner` for device discovery
- `MIDIEventHandler` logging MIDI messages
- `Core/Models/MusicalConcepts.swift` (Note, Chord, Interval, Scale)

**Deliverable:** App plays 4-bar chord progression with drums/bass, sees MIDI input

**Critical Files:**
- `/Audio/Synthesis/BackingTrackEngine.swift`
- `/Audio/Synthesis/SamplePlayer.swift`
- `/Audio/Synthesis/SynthesizerNode.swift`
- `/Audio/Synthesis/GroovePattern.swift` (NEW)
- `/MIDI/MIDIManager.swift`
- `/MIDI/MIDIDeviceScanner.swift`
- `/MIDI/MIDIEventHandler.swift`
- `/Core/Models/MusicalConcepts.swift`

**Validation:**
- Backing track plays with selected groove
- Can switch between groove styles
- MIDI device appears in device list
- MIDI input logged to console
- Drums and bass stay in sync
- Tempo changes affect backing track

---

### Week 3: Quantized Control + Animated Visualization
**Goal:** Foot pedal triggers chord changes, fretboard shows what to play

**Tasks:**
- `MIDICommandMapper` mapping pedal press → "next chord"
- `QuantizationEngine` snapping chord changes to grid
- `EventSequencer` scheduling chord changes with lookahead
- `AudioThreadSafeQueue` - lock-free ring buffer
- `MainThreadDispatcher` - safe UI updates from audio
- `FretboardView` with Canvas rendering
- `FretboardRenderer` for Canvas drawing
- `FretboardViewModel` displaying chord notes with theory overlay
- **Real-time note visualization system:**
  - Fretboard highlights notes as they should be played
  - Theory overlay shows intervals, scale degrees
  - Animated cursor/highlighting
- `PlaybackCursor` service (sample time → screen position)

**Deliverable:** Working practice loop - play along, change chords with pedal, see notes on fretboard

**Critical Files:**
- `/MIDI/MIDICommandMapper.swift`
- `/Audio/Sequencer/EventSequencer.swift`
- `/Audio/Sequencer/QuantizationEngine.swift`
- `/Audio/Threading/AudioThreadSafeQueue.swift`
- `/Audio/Threading/MainThreadDispatcher.swift`
- `/Features/Fretboard/Views/FretboardView.swift`
- `/Features/Fretboard/ViewModels/FretboardViewModel.swift`
- `/Rendering/FretboardRenderer.swift`
- `/Rendering/PlaybackCursor.swift`
- `/Core/Models/FretboardLayout.swift`
- `/Services/PracticeCoordinator.swift`

**Validation:**
- Pedal press triggers chord change on next beat
- Fretboard updates to show new chord
- Note highlighting synchronized with audio
- Theory overlay shows correct intervals
- No visual lag (< 50ms perceived)
- Quantization feels musical

---

### Week 4: Multi-Layout Visualization + Pattern Generator + Exercise Library
**Goal:** Complete visualization suite + algorithmic pattern generation + exercise library

**Tasks:**
- `NotationView` with scrolling cursor (MuseScore style)
- `NotationRenderer` for sheet music Canvas drawing
- `TABView` with playback cursor
- `TABRenderer` for tablature Canvas drawing
- `TimelineView` with chord block highlighting
- `TimelineRenderer` for timeline Canvas drawing
- **Algorithmic Pattern Generation System:**
  - `PatternGenerator` orchestrating pattern-to-notes conversion
  - `ScaleEngine` generating scale notes in any key
  - `PositionMapper` mapping notes to fretboard with fingering constraints
  - `SequenceBuilder` creating inversions, directions, rhythmic variations
  - `PatternDefinition` model (scale, chord types, sequences, position rules)
  - Support for random key selection (practice same pattern in all 12 keys)
- **Exercise JSON schema implementation:**
  - **Pattern-based exercises** with algorithmic generation
  - **Explicit exercises** with manually specified notes
  - **Hybrid exercises** combining both approaches
  - Position constraints (frets, fingers, string rules)
  - Pattern sequences (inversions, directions)
  - Rhythmic variations (upbeat, upbeat-downbeat)
  - Both absolute pitch (C4) and relative notation (scale degree 3)
  - Metadata (key, allowRandomKey, tempo, timeSignature, grooveStyle)
- **Author 20-30 example exercises:**
  - **Pattern-based** (15-20 exercises):
    - Major/minor scale patterns (3 notes per string, all positions)
    - 7th chord arpeggios (maj7, min7, dom7, min7b5) with inversions
    - Triad arpeggios (major, minor, diminished)
    - Diatonic intervals (3rds, 4ths, 5ths, 6ths)
    - Multiple rhythmic variations per pattern
    - All with random key support
  - **Explicit** (5-10 exercises):
    - I-IV-V progressions with simple melodies (various keys)
    - 12-bar blues with melody lines
    - Pop progressions with melody (I-V-vi-IV, etc.)
- `LoopRegion` with bar boundaries
- `ExerciseService` parsing JSON with pattern generation
- `ExerciseLibraryView` with categorized list
- `ExerciseLibraryViewModel` managing exercise state
- View switching logic (per exercise configuration)
- Polish and testing

**Deliverable:** Complete MVP - algorithmic exercises in random keys, full visualization, exercise library

**Critical Files:**
- `/Features/Notation/Views/NotationView.swift` (NEW)
- `/Features/Notation/ViewModels/NotationViewModel.swift` (NEW)
- `/Rendering/NotationRenderer.swift`
- `/Features/Notation/Views/TABView.swift` (NEW)
- `/Rendering/TABRenderer.swift`
- `/Features/Timeline/Views/TimelineView.swift` (NEW)
- `/Features/Timeline/ViewModels/TimelineViewModel.swift` (NEW)
- `/Rendering/TimelineRenderer.swift`
- `/Core/PatternGeneration/PatternGenerator.swift` (NEW)
- `/Core/PatternGeneration/ScaleEngine.swift` (NEW)
- `/Core/PatternGeneration/PositionMapper.swift` (NEW)
- `/Core/PatternGeneration/SequenceBuilder.swift` (NEW)
- `/Core/Models/PatternDefinition.swift` (NEW)
- `/Core/Models/Exercise.swift`
- `/Audio/Sequencer/LoopRegion.swift`
- `/Services/ExerciseService.swift`
- `/Features/ExerciseLibrary/Views/ExerciseListView.swift`
- `/Features/ExerciseLibrary/Views/ExerciseDetailView.swift`
- `/Features/ExerciseLibrary/ViewModels/ExerciseLibraryViewModel.swift`
- `/Resources/Exercises/patterns/*.json` (15-20 pattern files)
- `/Resources/Exercises/explicit/*.json` (5-10 explicit exercise files)

**Validation:**
- All visualization modes work (fretboard, notation, TAB, timeline)
- Can switch views during playback (where allowed by exercise)
- Notation cursor scrolls smoothly
- TAB highlights correct frets
- Timeline highlights current chord block
- **Pattern generator creates correct note sequences:**
  - All scale degrees respected
  - Inversions correctly applied
  - Position constraints enforced (frets, fingers, string rules)
  - Rhythmic variations applied correctly
- **Random key selection works** (same exercise in any key)
- Exercise library loads and displays all exercises
- Can filter by category/difficulty
- Loop region works seamlessly
- 60 FPS maintained during playback with complex patterns

**Note:** Week 4 extended by ~3-4 days to accommodate pattern generation system. This is a critical investment enabling exponentially more practice content.

---

## Phase 2: Enhanced Features (Weeks 5-8)

### Week 5-6: Advanced Fretboard + Theory Lessons
**Goal:** Rich learning features

**Tasks:**
- Advanced fretboard visualization with Alpha Jams-style overlays:
  - Fingering position suggestions
  - Scale pattern visualization
  - Interval relationships
  - Chord tone highlighting vs. passing tones
- Music theory lesson modules:
  - Interactive lessons embedded in exercises
  - Theory basics (intervals, chord construction)
  - Chord relationships (progressions, circle of fifths)
  - Rhythm/timing concepts
  - Scale patterns
- Lesson progression tracking

**Deliverable:** Educational features integrated into practice

---

### Week 7-8: Visual Exercise Editor + Settings
**Goal:** User can create exercises, customize app

**Tasks:**
- **Visual exercise editor:**
  - Drag-and-drop chord placement on timeline
  - Piano roll for melody note editing
  - Groove pattern selection
  - Key/tempo/time signature configuration
  - Preview playback
  - Export to JSON
  - Import from JSON
- Settings and preferences:
  - MIDI device configuration UI
  - Audio latency adjustment
  - Visual preferences (colors, note labeling)
  - Practice session history
  - User profile

**Deliverable:** Complete Phase 2 feature set

---

## Phase 3: Audio/Video Input (Future)

### Audio Input Features
- Pitch detection (MPM/YIN algorithm)
- Exercise validation (auto-pause when wrong note detected)
- Correctness evaluation with scoring
- Auto-pause-resume based on performance
- Gamification elements (streaks, achievements)

### Video Input Features (Ambitious)
- Guitar fretboard tracking via camera
- Finger placement analysis
- Technique feedback (hand position, finger angles)
- Computer vision for real-time tracking

### Learning Path
- Official method with structured curriculum
- Progressive difficulty levels
- Skill tree unlocking
- Personalized recommendations

---

## Exercise Content Plan

### Phase 1 Exercise Library (20-30 exercises)

#### Beginner (8-10 exercises)
- Basic I-IV-V in C, G, D
- Simple 2-chord progressions (Am-G, Em-D)
- 12-bar blues in E (simplified)
- Basic strumming patterns

#### Intermediate (8-10 exercises)
- I-V-vi-IV pop progressions (multiple keys)
- ii-V-I jazz patterns
- 12-bar blues with variations
- Melodies with chord accompaniment
- Syncopated rhythms

#### Advanced (4-6 exercises)
- Complex jazz progressions (vi-II-V-I, I-VI-ii-V)
- Blues with chord substitutions
- Modal progressions
- Intricate melodies over changes

#### Groove Variety
- Each progression available in multiple grooves:
  - Rock 8th, Rock 16th
  - Blues shuffle
  - Jazz swing, Bossa nova
  - Pop/ballad

---

## Milestone Checkpoints

### End of Week 1
- [ ] Audio engine plays metronome
- [ ] Tempo adjustable
- [ ] Basic UI functional

### End of Week 2
- [ ] Backing track with drums + bass plays
- [ ] 5-6 groove patterns implemented
- [ ] MIDI device connects
- [ ] Chord progression playback works

### End of Week 3
- [ ] MIDI triggers quantized chord changes
- [ ] Fretboard visualizes notes in real-time
- [ ] Lock-free audio-UI bridge working
- [ ] No audio glitches or visual lag

### End of Week 4 (MVP Complete)
- [ ] All visualization modes functional
- [ ] 20-30 exercises authored and loading
- [ ] Exercise library with categories
- [ ] Loop region works
- [ ] Audio-visual sync < 50ms
- [ ] 60 FPS during playback
- [ ] Audio latency < 20ms
- [ ] Ready for TestFlight

### End of Week 8 (Phase 2 Complete)
- [ ] Visual exercise editor functional
- [ ] Theory lessons integrated
- [ ] Advanced fretboard overlays
- [ ] Settings/preferences complete
- [ ] User can create custom exercises

---

## Risk Mitigation Schedule

### Week 1
- **Risk:** AudioKit integration issues
- **Action:** Test AudioKit early, have fallback plan for pure AVAudioEngine

### Week 2
- **Risk:** Groove pattern timing accuracy
- **Action:** Unit tests for beat scheduling, real hardware testing

### Week 3
- **Risk:** Lock-free queue bugs, MIDI jitter
- **Action:** Thread Sanitizer testing, extensive MIDI device testing

### Week 4
- **Risk:** Canvas rendering performance, complex exercise parsing
- **Action:** Profile with Instruments, optimize rendering, validate JSON schema

---

## Testing Schedule

### Continuous (All Weeks)
- Unit tests for new code
- Manual testing on simulator
- Git commits with descriptive messages

### Week 2
- First real hardware test (iPhone/iPad)
- MIDI device compatibility test

### Week 3
- Thread Sanitizer runs
- Audio latency measurement
- MIDI jitter measurement

### Week 4
- Full integration testing
- Performance profiling (Instruments)
- Test on multiple devices (iPhone 11, 13, iPad)
- Long-session stability test (10+ min)
- Final polish and bug fixes

---

## Success Metrics

### Phase 1 MVP
- **Technical:**
  - Audio latency < 20ms
  - MIDI jitter < 5ms
  - UI frame rate 60 FPS
  - Audio-visual sync < 50ms
  - Zero crashes in 10-minute session
- **Functional:**
  - All core features working
  - 20-30 exercises loading
  - All visualization modes functional
  - MIDI control working with multiple devices
- **Quality:**
  - Zero critical bugs
  - User can complete practice session end-to-end
  - App feels polished and responsive

### Phase 2
- Visual exercise editor creates valid exercises
- Theory lessons are clear and educational
- Advanced visualizations enhance learning

---

## Dependencies & Prerequisites

### Before Week 1
- [x] Architecture documentation complete
- [x] ADRs written
- [ ] Xcode project initialized
- [ ] SPM dependencies configured
- [ ] .gitignore for Xcode setup

### Before Week 2
- Audio engine working (Week 1 deliverable)
- Core models defined

### Before Week 3
- Backing track system working (Week 2 deliverable)
- MIDI connection established

### Before Week 4
- Visualization system architecture solid (Week 3 deliverable)
- Exercise JSON schema finalized

---

## Next Immediate Actions

1. Complete remaining architecture documentation (5 docs)
2. Write all 10 ADRs
3. Initialize Xcode project
4. Configure SPM dependencies
5. Set up project folder structure
6. Begin Week 1 implementation

---

**Related Documents:**
- [Architecture Overview](architecture/architecture-overview.md)
- [ADR Index](adr/README.md)
- [Epic Breakdown](epics/README.md)
- [Testing Strategy](testing-strategy.md)
