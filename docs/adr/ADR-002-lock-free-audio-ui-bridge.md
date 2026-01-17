# ADR-002: Lock-Free Audio-UI Bridge

**Date:** 2026-01-17
**Status:** Accepted
**Deciders:** Architecture team

## Context

SergeantMusic's audio engine runs on a real-time audio thread that must:
- Process audio buffers with < 20ms latency
- Never allocate memory
- Never acquire locks
- Never call Objective-C or touch UIKit/SwiftUI

However, the UI (running on main thread) needs to display:
- Current beat/bar position
- Current chord
- Playback state (playing/paused)

**Challenge:** How to communicate from audio thread → main thread without violating real-time constraints?

## Decision

Implement a **lock-free ring buffer** with atomic operations for audio → main thread communication, combined with **60 Hz polling** on the main thread.

## Rationale

### Why Lock-Free Queue?
1. **Real-Time Safe:** No locks = no priority inversion = predictable latency
2. **Industry Standard:** Used by all professional audio apps (DAWs, synthesizers)
3. **Proven Pattern:** Well-understood, extensively documented
4. **Performance:** Constant-time enqueue/dequeue operations
5. **Reliability:** No risk of deadlock or starvation

### Why 60 Hz Polling?
1. **Matches Display:** iOS displays refresh at 60 Hz (ProMotion at 120 Hz)
2. **Efficient:** Updates batched, not per-sample
3. **Sufficient Latency:** 16ms UI update latency is imperceptible
4. **Simple:** Timer-based, easy to implement and debug

### Alternatives Rejected

#### Option 1: @Published Properties (SwiftUI)
- **Problem:** Not thread-safe, requires main thread
- **Impact:** Would crash or cause priority inversion
- **Verdict:** ❌ Not real-time safe

#### Option 2: Dispatch Queue
- **Problem:** Uses locks internally
- **Impact:** Priority inversion, unpredictable latency
- **Verdict:** ❌ Not real-time safe

#### Option 3: Semaphores
- **Problem:** Blocking operation
- **Impact:** Audio thread could block = audio glitches
- **Verdict:** ❌ Not real-time safe

#### Option 4: NSNotificationCenter
- **Problem:** Involves Objective-C runtime, locks
- **Impact:** Allocations, unpredictable latency
- **Verdict:** ❌ Not real-time safe

## Implementation

### AudioThreadSafeQueue (Lock-Free Ring Buffer)
```swift
class AudioThreadSafeQueue<T> {
    private var buffer: UnsafeMutablePointer<T?>
    private let capacity: Int
    private var writeIndex = Atomic<Int>(0)  // Atomic operations
    private var readIndex = Atomic<Int>(0)

    // Audio thread writes (no locks!)
    func enqueue(_ value: T) -> Bool {
        // Lock-free implementation
    }

    // Main thread reads
    func dequeueAll() -> [T] {
        // Lock-free implementation
    }
}
```

### Usage Pattern
```swift
// Audio thread (real-time safe)
func audioRenderCallback() {
    // Process audio...

    // Notify UI (no locks!)
    audioEventQueue.enqueue(.beatChanged(currentBeat))
}

// Main thread (60 Hz)
Timer.publish(every: 0.016, on: .main, in: .common)
    .sink { _ in
        let events = audioEventQueue.dequeueAll()
        events.forEach { handleEvent($0) }
    }
```

## Consequences

### Positive
- ✅ Real-time safe (no locks, no allocations)
- ✅ Predictable latency (< 20ms audio + < 16ms UI = < 36ms total)
- ✅ Industry-proven pattern
- ✅ Scalable (works for any number of events)
- ✅ Testable with Thread Sanitizer

### Negative
- ❌ More complex than `@Published`
- ❌ Requires careful implementation (atomic operations)
- ❌ Fixed buffer size (can overflow if main thread stalls)
- ❌ Events can be batched/delayed up to 16ms

### Mitigation
- Use Thread Sanitizer to verify no data races
- Size buffer large enough (1024 events default)
- Monitor queue overflow (log warning if full)
- Add tests for concurrent access
- Document pattern clearly for team

## Technical Details

### Event Types
```swift
enum AudioEvent {
    case beatChanged(Double)
    case chordChanged(Chord)
    case playbackStateChanged(Bool)
    case loopCompleted
    case tempoChanged(Double)
}
```

### Atomic Operations
- Uses Swift Atomics or `os_unfair_lock` replacement
- Compare-and-swap (CAS) for index updates
- Memory ordering guarantees via atomic ops

### Buffer Sizing
- Default: 1024 events
- At 60 Hz: ~17 seconds of buffering
- Overflow is unlikely unless main thread blocked

## Verification

### Testing Strategy
1. **Unit Tests:** Queue operations (enqueue, dequeue, overflow)
2. **Thread Sanitizer:** Run with `-sanitize=thread` to detect races
3. **Stress Test:** Hammer queue from audio thread, verify no drops
4. **Performance Test:** Measure enqueue/dequeue latency (< 1μs target)

### Success Metrics
- Zero data races (Thread Sanitizer)
- Zero queue overflows in normal operation
- Audio-to-UI latency < 50ms (20ms audio + 16ms UI + margin)

## References
- [Audio Architecture](../architecture/audio-architecture.md)
- [State Management](../architecture/state-management.md)
- Real-Time Audio Programming 101 (Ross Bencina)
- Lock-Free Data Structures (Herb Sutter)

## Notes
This pattern is non-negotiable for real-time audio. Any alternative that uses locks will cause audio glitches due to priority inversion.
