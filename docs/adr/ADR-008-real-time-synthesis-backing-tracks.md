# ADR-008: Real-Time Synthesis for Backing Tracks

**Date:** 2026-01-17
**Status:** Accepted

## Context

Backing tracks could be:
1. Pre-rendered audio files (WAV/MP3)
2. Real-time synthesis from chord data
3. Hybrid (some rendered, some synthesized)

## Decision

Generate backing tracks in **real-time** from chord progression data, not pre-rendered audio.

## Rationale

### Why Real-Time?
- **Tempo Flexibility:** Change tempo without quality loss
- **Unlimited Progressions:** Any chord sequence works
- **Dynamic Groove:** Can change groove on the fly
- **Small Bundle:** No audio files (except drum samples)
- **Interactive:** Respond to MIDI commands instantly

### Why Not Pre-Rendered?
- **Fixed Tempo:** Would need multiple versions
- **Fixed Chords:** Cannot change progression
- **Huge Size:** 100MB+ for reasonable library
- **Inflexible:** Cannot adapt to user input

## Implementation

```swift
class BackingTrackEngine {
    func changeChord(_ chord: Chord, at time: AVAudioTime) {
        // Generate bass note from chord root
        let bassNote = chord.rootNote.midiNumber
        bassNode.playNote(bassNote, at: time)

        // Generate pad from chord voicing
        let padNotes = chord.notes.map { $0.midiNumber }
        padNode.playChord(padNotes, at: time)
    }
}
```

## Consequences

### Positive
- ✅ Tempo adjustment without artifacts
- ✅ Any chord progression works
- ✅ Small app bundle (~10MB vs 100MB+)
- ✅ Interactive (MIDI control)
- ✅ Can add groove variations easily

### Negative
- ❌ Higher CPU usage (~20-30%)
- ❌ Need synthesis implementation
- ❌ Slightly less realistic than studio recordings

### Mitigation
- Use efficient AudioKit synthesis
- Target < 30% CPU on iPhone 11
- Tune synthesis for musical sound
- Hybrid approach (samples for drums)

## CPU Budget

- Drums (samples): ~5%
- Bass (synthesis): ~5%
- Pads (synthesis): ~10%
- Total: ~20%
- Headroom: 80% remaining

## References
- [ADR-003: Hybrid Synthesis](ADR-003-hybrid-synthesis.md)
- [Audio Architecture](../architecture/audio-architecture.md)

## Notes
This is how GarageBand, Caustic, and most mobile DAWs work. Industry-proven approach.
