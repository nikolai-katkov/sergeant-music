# SergeantMusic - Technology Choices & Vision

**Date:** January 17, 2026
**Status:** Initial Brainstorming Phase

## Vision Summary

An iOS app for interactive guitar learning featuring:
- Real-time event-based sequencer with adjustable backing tracks
- Multiple visualization modes (fretboard, notation, chord grids, timeline)
- MIDI device integration for hands-free control
- Bite-sized music theory lessons integrated into practice
- Pre-built exercises focusing on chord progressions and rhythm
- Advanced fretboard visualization with theory overlays

## Key Decisions Made

### Platform & Deployment
- **Target:** iOS 16+ Universal (iPhone + iPad)
- **Reason:** Balances modern API availability with broad device reach
- **UI Framework:** SwiftUI
  - Declarative syntax ideal for complex, dynamic interfaces
  - Native performance and animations
  - Easy integration with Canvas for custom rendering

### Architecture
- **Pattern:** The Composable Architecture (TCA)
  - Unidirectional data flow crucial for complex state (audio + MIDI + UI)
  - Predictable state mutations prevent race conditions
  - Excellent testability for audio timing logic
  - Steeper learning curve but prevents common pitfalls
  - Rich ecosystem and documentation

### Audio Engine
- **Core:** AVAudioEngine + AudioKit wrapper
- **Latency Target:** 10-20ms (balanced)
- **Synthesis Approach:** Hybrid
  - Sample-based: Drums, bass (realistic sounds)
  - Synthesis: Pads, effects, metronome (procedural)
- **Rationale:** AudioKit abstracts real-time audio threading complexity while maintaining performance

### MIDI Integration
- **Protocols:** All major types supported
  - Bluetooth MIDI (primary, wireless convenience)
  - USB MIDI via Camera Adapter (broader device support)
  - Network MIDI (Mac/computer integration)
- **Core MIDI Framework:** Direct Apple APIs
- **Features:**
  - User-configurable MIDI mappings
  - Quantized chord changes triggered by foot pedals
  - Preset management for different devices

### Notation System
- **Rendering:** Core Graphics via SwiftUI Canvas
- **Data Model:** Custom AST (Abstract Syntax Tree)
  - Represents musical structures programmatically
  - Enables flexible rendering to different formats
- **Display Modes (all supported):**
  - Standard notation (treble clef)
  - Guitar tablature (TAB)
  - Chord diagrams/charts
  - Timeline/block visualization
- **Interactivity:** User-switchable layouts per exercise

### Data Storage
- **Primary:** Local file storage (JSON)
  - Simple to start, easy debugging
  - Version-controllable exercise formats
  - No backend dependencies for MVP
- **Future:** Migration path to CloudKit for sync

### Testing Strategy
- Unit tests (XCTest) for business logic
- Audio/MIDI integration tests for timing accuracy
- UI tests for SwiftUI views
- Manual device testing for latency validation

## MVP Scope (6-8 weeks)

### Core Features
1. **Event-based sequencer**
   - Beat-accurate scheduling
   - Tempo adjustment (40-240 BPM)
   - Quantization grid (1/4, 1/8, 1/16 notes)
   - Loop regions with bar boundaries

2. **Backing track engine**
   - Drum grooves (rock, blues, jazz, pop styles)
   - Bass line generator following chord roots
   - Click track/metronome

3. **Fretboard visualization**
   - Real-time chord display
   - Note highlighting during playback
   - Theory overlay: intervals, scale degrees, chord tones
   - Multiple visualization modes

4. **Basic MIDI integration**
   - Device discovery and connection
   - Programmable chord triggers
   - Quantized command execution

5. **Pre-built exercise library**
   - 20-30 curated chord progressions
   - Common patterns (12-bar blues, I-IV-V, ii-V-I)
   - Difficulty progression

### Deferred to Post-MVP
- Audio input analysis (pitch detection)
- Music theory lesson modules
- Full notation editor
- Exercise sharing/export
- Advanced groove customization

## Technology Stack Deep Dive

### Why SwiftUI Over UIKit?
- Declarative UI perfect for reactive state updates
- Canvas provides low-level drawing for notation
- Native animations for smooth fretboard updates
- Less boilerplate, faster iteration

### Why TCA Over MVVM?
- Complex state interactions (audio timeline + MIDI + UI)
- Time-based events require predictable state flow
- Built-in support for effects (MIDI, audio, timers)
- Testing strategy for async audio operations
- **Trade-off:** Steeper learning curve, needs extensive documentation

### Why AudioKit?
- Abstracts Audio Unit (AUGraph) complexity
- Real-time safe abstractions
- Built-in sample player and synthesis nodes
- Active community, iOS-focused
- **Alternative considered:** Pure AVAudioEngine
  - Rejected: Too low-level for MVP timeline

### Why Custom Notation AST?
- Flexible representation of musical concepts
- Single source of truth for multiple renderings
- Enables algorithmic composition features
- Type-safe music theory operations
- **Alternative considered:** MusicXML parsing
  - Rejected: Overkill for chord-focused app

### Why Core Graphics Over Metal?
- Notation rendering isn't GPU-intensive
- Simpler integration with SwiftUI
- Canvas provides declarative drawing
- Metal reserved for future 3D fretboard view

## Music Theory Coverage

Bite-sized lessons integrated into practice:
1. **Theory Basics**
   - Note names, intervals
   - Chord construction (triads, 7ths)
   - Scale degrees and functions

2. **Chord Relationships**
   - Diatonic progressions
   - Circle of fifths
   - Common substitutions

3. **Rhythm/Timing**
   - Note values, time signatures
   - Subdivision, syncopation
   - Groove patterns

4. **Scale Patterns**
   - Major/minor scales
   - Pentatonics
   - Modal applications

## Visualization Modes

User-switchable per exercise:

1. **Guitar Fretboard** (inspired by oolimo.com)
   - Horizontal fretboard, 12-15 frets visible
   - Note dots with labels (note name, interval, or scale degree)
   - Color coding for chord tones vs. passing tones

2. **Note Sheet** (like MuseScore)
   - Traditional staff notation
   - Playback cursor tracking
   - TAB notation below staff

3. **Chord Grid** (inspired by iReal Pro)
   - Timeline with chord blocks
   - Bar divisions clearly marked
   - Chord diagrams inline

4. **Chord Sheet**
   - Lyrics/slash notation style
   - Simple chord changes over time grid
   - Minimal visual complexity

## Open Questions & Future Considerations

### Technical
- Sample library licensing (drums, bass sounds)
- AudioKit version (stable release vs. latest)
- TCA dependency management (Swift Package Manager)
- Background audio session handling

### Product
- Monetization strategy (affects architecture decisions)
- User progression tracking requirements
- Social features (sharing, leaderboards)
- Integration with external content (backing track imports)

### Audio Input Feature (Ambitious/Future)
- Pitch detection algorithms (MPM, YIN, PYIN)
- Real-time FFT for frequency analysis
- Machine learning for technique evaluation
- Microphone permission and privacy
- **Complexity:** High - recommend separate research phase

## Next Steps

1. **Solidify Architecture Decisions**
   - Review TCA patterns with stakeholder
   - Validate audio framework choice (AudioKit vs. pure AVAudioEngine)
   - Confirm notation rendering approach

2. **Create Detailed Documentation**
   - Architecture decision records (ADRs)
   - Technical roadmap with milestones
   - Epic breakdown with user stories
   - API design for core modules

3. **Project Setup**
   - Initialize Xcode project
   - Configure SPM dependencies
   - Set up TCA boilerplate
   - Create initial module structure

4. **Prototyping Priorities**
   - Audio engine proof-of-concept
   - MIDI device connection flow
   - Notation Canvas rendering spike
   - Fretboard visualization prototype

---

**Note:** This document captures initial brainstorming. As decisions solidify, they will be formalized in proper architecture documents, ADRs, and technical specifications.
