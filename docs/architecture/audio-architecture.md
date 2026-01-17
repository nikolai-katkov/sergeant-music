# Audio Architecture

## Overview

SergeantMusic's audio subsystem handles real-time audio synthesis, sequencing, and backing track generation. This document details the architecture, threading model, and critical patterns for audio processing.

## Core Requirements

- **Low Latency:** < 20ms audio latency (256-sample buffer at 44.1kHz)
- **Sample Accuracy:** Event scheduling accurate to single samples
- **Real-Time Safe:** No allocations or locks on audio thread
- **Beat Synchronization:** Tight sync between sequencer and audio playback
- **Dynamic Synthesis:** Generate backing tracks in real-time (not pre-rendered)

## Technology Stack

### AVAudioEngine (Apple's Audio Framework)
- Core audio graph management
- Node-based architecture
- Low-level access to audio buffers
- AV

AudioTime for sample-accurate timing

### AudioKit (Abstraction Layer)
- Simplifies Audio Unit (AUGraph) complexity
- Real-time safe abstractions
- Built-in sample player and synthesis nodes
- Active iOS-focused community
- Version: 5.6+ (latest stable)

### Why AudioKit?
- **Abstracts complexity:** Don't need to understand Audio Units deeply
- **Real-time safe:** Designed for low-latency audio
- **Sample library:** Built-in drum sample playback
- **Synthesis:** Built-in oscillators for bass/pads
- **Community:** Good documentation and examples

## Audio Subsystem Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Audio Subsystem                         │
│                  (Audio Thread)                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         AudioEngineManager                        │  │
│  │  - AVAudioEngine lifecycle                        │  │
│  │  - Audio session configuration                    │  │
│  │  - Node graph management                          │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │         EventSequencer                            │  │
│  │  - Sample-accurate event scheduling              │  │
│  │  - MusicalClock (tempo, beats, bars)             │  │
│  │  - Quantization engine                            │  │
│  │  - Loop region management                         │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │      BackingTrackEngine                           │  │
│  │  - Coordinates all instruments                    │  │
│  │  - Chord → notes conversion                       │  │
│  └─────┬──────────────────────────┬─────────────────┘  │
│        │                          │                      │
│  ┌─────┴──────────┐      ┌───────┴──────────┐          │
│  │  SamplePlayer  │      │ SynthesizerNode  │          │
│  │  (Drums)       │      │ (Bass, Pads)     │          │
│  └────────────────┘      └──────────────────┘          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │    AudioThreadSafeQueue (Lock-Free)               │  │
│  │  - Audio thread → Main thread events             │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
                    Main Thread
```

## Key Components

### 1. AudioEngineManager

**Responsibility:** Manages AVAudioEngine lifecycle and audio session.

**Key Tasks:**
- Initialize AVAudioEngine
- Configure audio session (category, mode, buffer size)
- Build audio node graph
- Handle audio interruptions (phone calls, etc.)
- Start/stop audio engine
- Monitor performance (CPU, buffer underruns)

**File:** `/Audio/AudioEngine/AudioEngineManager.swift`

```swift
class AudioEngineManager {
    private let engine: AVAudioEngine
    private let session: AVAudioSession

    // Audio nodes
    private let mainMixerNode: AVAudioMixerNode
    private var samplePlayerNodes: [AVAudioPlayerNode] = []

    func initialize() throws {
        // Configure audio session
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(256.0 / 44100.0) // 256 samples
        try session.setActive(true)

        // Build audio graph
        buildAudioGraph()

        // Prepare engine
        engine.prepare()
    }

    func start() throws {
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}
```

### 2. EventSequencer

**Responsibility:** Sample-accurate event scheduling and musical timing.

**Key Tasks:**
- Track current playback position (sample time, beat, bar)
- Schedule events at precise sample times
- Quantize incoming MIDI commands to grid
- Manage loop regions
- Publish playback position for visualization

**File:** `/Audio/Sequencer/EventSequencer.swift`

**Critical Pattern: Sample-Accurate Scheduling**

```swift
class EventSequencer {
    private let audioEngine: AVAudioEngine
    private var scheduledEvents: [(time: AVAudioTime, event: SequencerEvent)] = []

    // Called from MIDI handler (audio queue)
    func scheduleEvent(_ event: SequencerEvent, at beat: Double) {
        let sampleTime = beatToSampleTime(beat, tempo: currentTempo)
        let audioTime = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)

        // Insert in sorted order
        scheduledEvents.append((audioTime, event))
        scheduledEvents.sort { $0.time.sampleTime < $1.time.sampleTime }
    }

    // Called from audio render callback
    func processEvents(currentTime: AVAudioTime, bufferSize: AVAudioFrameCount) {
        let endTime = currentTime.sampleTime + Int64(bufferSize)

        // Execute all events in this buffer
        while let next = scheduledEvents.first,
              next.time.sampleTime < endTime {
            executeEvent(next.event, at: next.time)
            scheduledEvents.removeFirst()
        }
    }

    private func executeEvent(_ event: SequencerEvent, at time: AVAudioTime) {
        switch event {
        case .chordChange(let chord):
            backingTrackEngine.changeChord(chord, at: time)
            notifyMainThread(.chordChanged(chord))
        case .loopEnd:
            scheduleLoopEvents()
        }
    }
}
```

### 3. MusicalClock

**Responsibility:** Convert between musical time (beats/bars) and sample time.

**Key Tasks:**
- Track tempo (BPM)
- Track time signature
- Calculate beat position from samples
- Calculate sample position from beats
- Handle tempo changes

**File:** `/Audio/Sequencer/MusicalClock.swift`

```swift
class MusicalClock {
    var tempo: Double = 120 // BPM
    var timeSignature: TimeSignature = .fourFour
    let sampleRate: Double = 44100

    // Samples per beat at current tempo
    var samplesPerBeat: Double {
        return (60.0 / tempo) * sampleRate
    }

    // Convert beat to sample time
    func beatToSampleTime(_ beat: Double) -> Int64 {
        return Int64(beat * samplesPerBeat)
    }

    // Convert sample time to beat
    func sampleTimeToBeat(_ sampleTime: Int64) -> Double {
        return Double(sampleTime) / samplesPerBeat
    }

    // Get current bar number
    func sampleTimeToBar(_ sampleTime: Int64) -> Int {
        let beat = sampleTimeToBeat(sampleTime)
        return Int(beat / Double(timeSignature.beatsPerBar))
    }
}
```

### 4. BackingTrackEngine

**Responsibility:** Generate real-time backing tracks from chord progressions.

**Key Tasks:**
- Coordinate drum, bass, and pad instruments
- Load and apply groove patterns
- Convert chords to notes for bass/pads
- Schedule instrument events
- Handle chord changes

**File:** `/Audio/Synthesis/BackingTrackEngine.swift`

```swift
class BackingTrackEngine {
    private let drumPlayer: SamplePlayer
    private let bassNode: SynthesizerNode
    private let padNode: SynthesizerNode

    private var currentGroove: GroovePattern?
    private var currentChord: Chord?

    func loadExercise(_ exercise: Exercise) {
        currentGroove = loadGroovePattern(exercise.grooveStyle)
        scheduleInitialEvents(exercise)
    }

    func changeChord(_ chord: Chord, at time: AVAudioTime) {
        currentChord = chord

        // Update bass to play chord root
        let bassNote = chord.rootNote.midiNumber
        bassNode.playNote(bassNote, at: time)

        // Update pad to play chord voicing
        let padNotes = chord.notes.map { $0.midiNumber }
        padNode.playChord(padNotes, at: time)
    }

    private func scheduleGrooveEvents(_ groove: GroovePattern, from: AVAudioTime) {
        // Schedule drum hits
        for hit in groove.drumHits {
            let hitTime = AVAudioTime(sampleTime: from.sampleTime + hit.offset,
                                     atRate: from.sampleRate)
            drumPlayer.playSound(hit.sound, at: hitTime)
        }

        // Schedule bass notes
        for note in groove.bassPattern {
            guard let chord = currentChord else { continue }
            let bassNote = chord.rootNote.transposed(by: note.interval)
            let noteTime = AVAudioTime(sampleTime: from.sampleTime + note.offset,
                                       atRate: from.sampleRate)
            bassNode.playNote(bassNote.midiNumber, at: noteTime, duration: note.duration)
        }
    }
}
```

### 5. SamplePlayer (Drums)

**Responsibility:** Play drum samples with precise timing.

**Technology:** AVAudioPlayerNode + audio files

**Key Tasks:**
- Load drum samples into memory (kick, snare, hi-hat, crash, ride)
- Schedule sample playback at specific AVAudioTime
- Handle sample variations (velocity, round-robin)

**File:** `/Audio/Synthesis/SamplePlayer.swift`

```swift
class SamplePlayer {
    private let engine: AVAudioEngine
    private var playerNodes: [DrumSound: AVAudioPlayerNode] = [:]
    private var audioFiles: [DrumSound: AVAudioFile] = [:]

    func loadSamples() throws {
        for sound in DrumSound.allCases {
            let url = Bundle.main.url(forResource: sound.filename, withExtension: "wav")!
            let file = try AVAudioFile(forReading: url)
            audioFiles[sound] = file

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            playerNodes[sound] = player

            player.play()
        }
    }

    func playSound(_ sound: DrumSound, at time: AVAudioTime) {
        guard let player = playerNodes[sound],
              let file = audioFiles[sound] else { return }

        player.scheduleFile(file, at: time)
    }
}
```

### 6. SynthesizerNode (Bass, Pads)

**Responsibility:** Real-time synthesis for bass and pad sounds.

**Technology:** AudioKit oscillators and filters

**Key Tasks:**
- Generate waveforms (sine, saw, square)
- Apply ADSR envelopes
- Play notes at specific times
- Handle note on/off

**File:** `/Audio/Synthesis/SynthesizerNode.swift`

```swift
import AudioKit

class SynthesizerNode {
    private let oscillator: AKOscillatorBank
    private let filter: AKMoogLadder
    private let envelope: AKAmplitudeEnvelope

    func playNote(_ midiNote: Int, at time: AVAudioTime, duration: Double = 0.5) {
        // Convert AVAudioTime to AudioKit time
        let akTime = convertToAudioKitTime(time)

        // Schedule note on
        oscillator.play(noteNumber: MIDINoteNumber(midiNote),
                       velocity: 80,
                       at: akTime)

        // Schedule note off
        let offTime = akTime + duration
        oscillator.stop(noteNumber: MIDINoteNumber(midiNote), at: offTime)
    }

    func playChord(_ midiNotes: [Int], at time: AVAudioTime) {
        for note in midiNotes {
            playNote(note, at: time, duration: 1.0)
        }
    }
}
```

## Threading Model

### The Golden Rule
**The audio render thread MUST NEVER:**
- Allocate memory
- Acquire locks (mutexes, semaphores)
- Call Objective-C methods
- Touch UIKit/SwiftUI
- Access @Published properties
- Call `print()` or log

### Audio Thread (Real-Time Priority)

**What it does:**
- Processes audio buffers (typically 256-512 samples)
- Schedules events
- Updates musical clock
- Generates audio samples
- Enqueues UI events to lock-free queue

**What it CANNOT do:**
- Allocate memory
- Use locks
- Update UI

**Implementation:**
```swift
func audioRenderCallback(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
    // ✅ OK: Read pre-allocated data
    let events = scheduledEvents

    // ✅ OK: Process events
    processEvents(currentTime: time, bufferSize: buffer.frameLength)

    // ✅ OK: Update clock (in-place)
    musicalClock.advance(by: buffer.frameLength)

    // ✅ OK: Enqueue event (lock-free)
    audioEventQueue.enqueue(.beatChanged(musicalClock.currentBeat))

    // ❌ BAD: Allocate
    // let newArray = [1, 2, 3]  // CRASH!

    // ❌ BAD: Lock
    // mutex.lock()  // PRIORITY INVERSION!

    // ❌ BAD: UI update
    // viewModel.currentBeat = beat  // CRASH!
}
```

### Main Thread (UI Thread)

**What it does:**
- Handles all SwiftUI updates
- Receives audio events via lock-free queue
- Updates @Published properties in ViewModels
- Sends commands to audio thread

**60 Hz Update Loop:**
```swift
Timer.publish(every: 0.016, on: .main, in: .common)
    .autoconnect()
    .sink { [weak self] _ in
        // Dequeue all audio events
        let events = self?.audioEventQueue.dequeueAll() ?? []

        // Update ViewModels
        events.forEach { event in
            self?.handleAudioEvent(event)
        }
    }
```

### Audio Queue (Serial Dispatch Queue)

**Purpose:** Safe zone for audio operations that aren't real-time critical.

**What runs here:**
- Audio engine start/stop
- Loading samples
- Building audio graph
- MIDI event initial processing
- Scheduling future events

**Implementation:**
```swift
let audioQueue = DispatchQueue(label: "com.sergeantmusic.audio",
                               qos: .userInteractive)

// User presses play button (main thread)
func play() {
    audioQueue.async { [weak self] in
        self?.sequencer.start()
    }
}
```

## Lock-Free Communication

### AudioThreadSafeQueue

**Purpose:** Pass events from audio thread → main thread without locks.

**Implementation:** Lock-free ring buffer with atomic operations.

**File:** `/Audio/Threading/AudioThreadSafeQueue.swift`

```swift
class AudioThreadSafeQueue<T> {
    private var buffer: UnsafeMutablePointer<T?>
    private let capacity: Int
    private var writeIndex = Atomic<Int>(0)
    private var readIndex = Atomic<Int>(0)

    init(capacity: Int = 1024) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<T?>.allocate(capacity: capacity)
        buffer.initialize(repeating: nil, count: capacity)
    }

    // Audio thread writes here (no locks!)
    func enqueue(_ value: T) -> Bool {
        let currentWrite = writeIndex.load()
        let nextWrite = (currentWrite + 1) % capacity

        if nextWrite == readIndex.load() {
            return false // Queue full
        }

        buffer[currentWrite] = value
        writeIndex.store(nextWrite)
        return true
    }

    // Main thread reads here
    func dequeueAll() -> [T] {
        var result: [T] = []

        while readIndex.load() != writeIndex.load() {
            let currentRead = readIndex.load()
            if let value = buffer[currentRead] {
                result.append(value)
                buffer[currentRead] = nil
            }
            readIndex.store((currentRead + 1) % capacity)
        }

        return result
    }
}
```

## Audio Session Configuration

### Latency vs Battery Trade-off

```swift
class AudioSessionManager {
    func configure(for scenario: AudioScenario) throws {
        let session = AVAudioSession.sharedInstance()

        switch scenario {
        case .practice:
            // Low latency for interactive practice
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setPreferredIOBufferDuration(256.0 / 44100.0) // 5.8ms
            try session.setPreferredSampleRate(44100)

        case .casual:
            // Higher latency OK, save battery
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setPreferredIOBufferDuration(512.0 / 44100.0) // 11.6ms
            try session.setPreferredSampleRate(44100)
        }

        try session.setActive(true)
    }

    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio session interrupted (phone call, etc.)
            pausePlayback()

        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumePlayback()
            }
        @unknown default:
            break
        }
    }
}
```

## Performance Monitoring

### Key Metrics

1. **Audio Latency:** < 20ms target
   - Measure: Input → Output round-trip
   - Tool: Audio latency test app

2. **CPU Usage:** < 50% sustained
   - Measure: Xcode Instruments (Time Profiler)
   - Watch for: Hot spots in audio callback

3. **Buffer Underruns:** Zero tolerance
   - Symptom: Audio glitches, pops, clicks
   - Fix: Optimize audio callback, increase buffer size

4. **Memory Allocations:** Zero on audio thread
   - Measure: Instruments (Allocations)
   - Watch for: Unexpected allocations in callback

### Monitoring Code

```swift
class AudioPerformanceMonitor {
    private var cpuLoad: Float = 0

    func updateMetrics() {
        if let engine = audioEngine {
            // CPU load
            cpuLoad = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate > 0
                ? Float(engine.outputNode.numberOfInputs) : 0

            // Log if high
            if cpuLoad > 0.7 {
                print("⚠️ High CPU load: \(cpuLoad * 100)%")
            }
        }
    }
}
```

## Testing Strategy

### Unit Tests
- Musical time conversions (beat ↔ sample)
- Quantization logic
- Event scheduling order
- Clock arithmetic

### Integration Tests
- Audio engine lifecycle (start/stop/restart)
- Sample playback timing
- Synthesis note accuracy
- Loop region boundaries

### Thread Sanitizer
- Run with Thread Sanitizer enabled
- Catch data races in lock-free code
- Verify no locks in audio callback

### Real Hardware Testing
- Measure actual latency on device
- Test on iPhone 11 (older hardware)
- Long session stability (10+ min)
- Background audio handling

## Critical Risks & Mitigations

### Risk 1: Audio Glitches
**Cause:** Allocations or locks on audio thread
**Detection:** Audible pops/clicks
**Fix:** Profile with Instruments, remove allocations

### Risk 2: High Latency
**Cause:** Large buffer size, inefficient callback
**Detection:** Sluggish feel, delayed response
**Fix:** Reduce buffer size, optimize callback

### Risk 3: Thread Priority Inversion
**Cause:** Main thread holding lock that audio thread needs
**Detection:** Audio glitches under UI load
**Fix:** Use lock-free queue, never share locks

## Next Steps

1. Implement AudioEngineManager
2. Implement lock-free queue
3. Implement MusicalClock
4. Implement EventSequencer
5. Add SamplePlayer for drums
6. Add SynthesizerNode for bass
7. Profile and optimize

---

**Related Documents:**
- [Architecture Overview](architecture-overview.md)
- [MVVM vs TCA Comparison](mvvm-vs-tca-comparison.md)
- [MIDI Architecture](midi-architecture.md)
- [ADR-003: Hybrid Synthesis](../adr/ADR-003-hybrid-synthesis.md)
