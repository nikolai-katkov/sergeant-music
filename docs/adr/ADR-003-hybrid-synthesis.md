# ADR-003: Hybrid Synthesis for Backing Tracks

**Date:** 2026-01-17
**Status:** Accepted
**Deciders:** Architecture team, Audio engineer

## Context

SergeantMusic needs backing track generation with:
- Realistic drum sounds
- Musical bass lines
- Pad/atmospheric sounds
- Low CPU usage
- Adjustable tempo without artifacts
- Multiple groove styles

We need to decide: Sample-based playback vs Synthesis vs Hybrid approach.

## Decision

Use **hybrid approach**: Sample-based playback for drums, synthesis for bass and pads.

## Rationale

### Drums: Sample-Based
**Why samples?**
- **Realism:** Acoustic drums are hard to synthesize convincingly
- **CPU Efficient:** Playback is cheaper than synthesis
- **Quality:** Professional drum samples available
- **Variety:** Easy to swap different kit sounds

**Trade-off:** Larger app bundle (5-10MB for drum samples)

### Bass: Synthesis
**Why synthesis?**
- **Flexibility:** Any note/pitch on demand
- **CPU Efficient:** Simple waveform + filter
- **Small Footprint:** No sample files needed
- **Consistent:** Predictable tone across range

**Trade-off:** Less realistic than sampled bass guitar

### Pads/Atmosphere: Synthesis
**Why synthesis?**
- **Sustained Sounds:** Synthesis excels at pads
- **CPU Efficient:** Fewer samples to manage
- **Variety:** Easy to create different timbres
- **Small Footprint:** Procedural generation

## Implementation

### Technology Stack
- **AVAudioEngine:** Core audio graph
- **AudioKit 5.6+:** Synthesis and sample playback abstractions
- **AVAudioPlayerNode:** For drum samples
- **AudioKit Oscillator:** For bass/pad synthesis

### Drum Sample Library
- Kick: 3 variations (for round-robin)
- Snare: 3 variations
- Hi-hat closed: 2 variations
- Hi-hat open: 2 variations
- Crash cymbal: 2 variations
- Ride cymbal: 2 variations

**Total:** ~15 samples, ~8-10MB uncompressed

### Bass Synthesis
- **Waveform:** Sawtooth or square wave
- **Filter:** Low-pass filter (Moog ladder style)
- **Envelope:** ADSR (short attack, medium decay, high sustain, short release)
- **Octave:** Follow chord root, one octave below

### Pad Synthesis
- **Waveform:** Multiple detuned oscillators (fat sound)
- **Filter:** Slow filter sweep
- **Envelope:** Slow attack, long release (pad-like)
- **Voicing:** Play full chord voicing

## Consequences

### Positive
- ✅ Realistic drum sounds (samples)
- ✅ Flexible bass/pad sounds (synthesis)
- ✅ Reasonable app bundle size (~10MB)
- ✅ CPU efficient (hybrid approach)
- ✅ Tempo independent (no pitch shifting)
- ✅ Easy to implement with AudioKit

### Negative
- ❌ Drum samples increase bundle size
- ❌ Bass/pads less realistic than sampled instruments
- ❌ Need to license or create drum samples
- ❌ Multiple sample files to manage

### Mitigation
- Use royalty-free drum samples (CC0 or purchased license)
- Optimize samples (mono, compressed)
- Consider on-demand download for additional kits (future)
- Tune synthesis parameters for musical sound

## Alternatives Considered

### Option 1: Pure Sample-Based
**Pros:**
- Realistic sound for all instruments
- No synthesis complexity

**Cons:**
- Huge bundle size (100MB+)
- Tempo changes require time-stretching (quality loss)
- Inflexible (pre-recorded patterns only)

**Verdict:** ❌ Too large, not flexible enough

### Option 2: Pure Synthesis
**Pros:**
- Tiny bundle size
- Ultimate flexibility
- Tempo independent

**Cons:**
- Drums sound synthetic/unrealistic
- Requires expertise to make musical
- CPU intensive for realistic sounds

**Verdict:** ❌ Drums won't sound good enough

### Option 3: Rendered Audio Files
**Pros:**
- Guaranteed quality
- No real-time processing

**Cons:**
- Cannot change tempo
- Cannot change chords
- Huge file sizes

**Verdict:** ❌ Not flexible enough for practice app

## Sample Licensing

### Requirements
- Royalty-free or Creative Commons
- Commercial use allowed
- No attribution required (preferred)

### Potential Sources
1. **Purchased Libraries:**
   - Splice
   - Sounds.com
   - Native Instruments

2. **Free Libraries:**
   - Freesound.org (check individual licenses)
   - 99Sounds
   - Bedroom Producers Blog

3. **Custom Recording:**
   - Record custom drum kit (requires equipment)
   - Hire session drummer
   - Use electronic drum kit

**Decision:** Start with purchased royalty-free library (~$50-100)

## Performance Targets

### CPU Usage
- Target: < 30% on iPhone 11
- Drums (samples): ~5% CPU
- Bass (synthesis): ~5% CPU
- Pads (synthesis): ~10% CPU
- Headroom: ~50% for other features

### Memory
- Drum samples loaded at startup: ~20MB RAM
- Synthesis: Minimal memory (< 1MB)
- Total audio memory budget: ~30MB

## Future Enhancements

### Phase 2+
- Multiple drum kit options (rock, jazz, electronic)
- Advanced synthesis (FM, wavetable)
- User-selectable instruments
- Third-party sample library import

## Technical Implementation

### File Organization
```
Resources/
  Samples/
    Drums/
      kick-01.wav
      kick-02.wav
      snare-01.wav
      ...
```

### Code Structure
```swift
class BackingTrackEngine {
    let drumPlayer: SamplePlayer      // Samples
    let bassNode: SynthesizerNode     // Synthesis
    let padNode: SynthesizerNode      // Synthesis
}
```

## References
- [Audio Architecture](../architecture/audio-architecture.md)
- AudioKit Documentation
- iOS Audio Programming Guide

## Review Trigger
Reassess if:
- Synthesis sounds too artificial (user feedback)
- CPU usage exceeds 50%
- Bundle size exceeds 50MB
- Better synthesis libraries become available

## Notes
This hybrid approach balances realism, flexibility, and bundle size. It's the same approach used by many mobile music apps (GarageBand, etc.).
