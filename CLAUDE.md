# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SergeantMusic** - iOS guitar learning app with real-time audio sequencing, MIDI integration, and interactive practice features.

**Current Phase:** Documentation Complete → Ready for Phase 1 Implementation

## Technology Stack

- **Platform:** iOS 16+ Universal (iPhone + iPad)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Audio:** AVAudioEngine + AudioKit 5.6+
- **MIDI:** Core MIDI (Bluetooth, USB, Network)
- **Architecture:** MVVM + Coordinators (Phase 1)
- **Rendering:** SwiftUI Canvas + Core Graphics
- **Storage:** Local JSON files with Codable

## Repository Structure

```
SergeantMusic/
├── docs/
│   ├── architecture/           # System architecture documentation
│   │   ├── architecture-overview.md      # Complete 8-layer system design
│   │   ├── audio-architecture.md         # Real-time audio patterns
│   │   ├── midi-architecture.md          # MIDI integration
│   │   ├── state-management.md           # PracticeCoordinator pattern
│   │   ├── visualization-architecture.md # Multi-layout visualization
│   │   └── mvvm-vs-tca-comparison.md     # Architecture comparison
│   ├── adr/                    # Architecture Decision Records (ADR-001 to ADR-011)
│   ├── epics/                  # Epic breakdowns with user stories
│   ├── brainstorming/          # Early planning documents
│   ├── exercise-json-schema.md # Exercise JSON specification
│   └── roadmap.md              # Week-by-week implementation plan
└── .claude/                    # Claude Code configuration
```

## Development Status

**Phase:** Documentation Complete (All ADRs, architecture docs, roadmap, epics)

**Next Step:** Begin Phase 1 Implementation - Week 1 (Audio Foundation)

## Key Architecture Decisions

All architectural decisions are documented in ADRs (Architecture Decision Records):

1. **ADR-001:** MVVM for Phase 1 (lower learning curve, audio-agnostic)
2. **ADR-002:** Lock-free audio-UI bridge (ring buffer + 60Hz polling)
3. **ADR-003:** Hybrid synthesis (samples for drums, synthesis for bass/pads)
4. **ADR-004:** JSON exercise storage (local files with Codable)
5. **ADR-005:** SwiftUI Canvas rendering (60 FPS target)
6. **ADR-006:** Full arrangement exercise model
7. **ADR-007:** Shared playback cursor (visualization sync)
8. **ADR-008:** Real-time synthesis backing tracks
9. **ADR-009:** Manual JSON + algorithmic generation
10. **ADR-010:** Flexible notation format (absolute + relative)
11. **ADR-011:** Algorithmic pattern generator in Phase 1 MVP

## Critical Technical Patterns

### Real-Time Audio Threading
- **Golden Rule:** Audio thread MUST NEVER allocate memory, acquire locks, or call Objective-C
- Lock-free ring buffer for audio → main thread communication
- 60 Hz polling on main thread for UI updates
- Sample-accurate event scheduling with AVAudioTime

### Pattern Generation System
Most exercises are algorithmic (not manually authored):
- One pattern definition → infinite variations
- Random key practice (same exercise in all 12 keys)
- Position-based constraints (frets, fingers, string rules)
- Components: PatternGenerator, ScaleEngine, PositionMapper, SequenceBuilder

### Performance Targets
- Audio latency: < 20ms
- MIDI jitter: < 5ms
- UI frame rate: 60 FPS sustained
- Audio-visual sync: < 50ms perceived delay
- Pattern generation: < 100ms for complex patterns

## Module Structure (Planned)

```
SergeantMusic/
├── App/                        # App lifecycle, coordination
├── Core/
│   ├── Models/                 # Domain models (Note, Chord, Exercise)
│   └── PatternGeneration/      # Pattern generator subsystem
│       ├── PatternGenerator.swift
│       ├── ScaleEngine.swift
│       ├── PositionMapper.swift
│       └── SequenceBuilder.swift
├── Audio/                      # Real-time audio subsystem
│   ├── AudioEngine/
│   ├── Sequencer/
│   ├── Synthesis/
│   └── Threading/              # Lock-free queue
├── MIDI/                       # MIDI subsystem
├── Features/                   # MVVM feature modules
│   ├── Practice/
│   ├── Fretboard/
│   ├── Notation/
│   ├── Timeline/
│   ├── ExerciseLibrary/
│   └── Settings/
├── Services/                   # Business logic (PracticeCoordinator)
├── Rendering/                  # Canvas renderers
└── Resources/
    ├── Exercises/
    │   ├── patterns/           # Pattern-based exercises (15-20)
    │   └── explicit/           # Explicit exercises (5-10)
    └── Samples/                # Drum samples
```

## Essential Reading Before Implementation

**Start Here:**
1. [docs/architecture/architecture-overview.md](docs/architecture/architecture-overview.md) - Complete system design
2. [docs/roadmap.md](docs/roadmap.md) - Week-by-week implementation plan
3. [docs/exercise-json-schema.md](docs/exercise-json-schema.md) - Exercise data format

**Critical for Audio Work:**
4. [docs/architecture/audio-architecture.md](docs/architecture/audio-architecture.md) - Real-time audio patterns
5. [docs/adr/ADR-002-lock-free-audio-ui-bridge.md](docs/adr/ADR-002-lock-free-audio-ui-bridge.md) - Thread safety

**Critical for Pattern Generator:**
6. [docs/adr/ADR-011-algorithmic-pattern-generator.md](docs/adr/ADR-011-algorithmic-pattern-generator.md)
7. [docs/epics/epic-7-pattern-generation-system.md](docs/epics/epic-7-pattern-generation-system.md)

## Phase 1 MVP Roadmap (4 Weeks)

**Week 1: Audio Foundation**
- AudioEngineManager, MusicalClock, MetronomeNode
- Deliverable: Metronome at adjustable tempo

**Week 2: Backing Tracks + MIDI**
- BackingTrackEngine, 5-6 groove patterns, MIDI device discovery
- Deliverable: Backing tracks with MIDI input

**Week 3: Quantized Control + Visualization**
- MIDICommandMapper, QuantizationEngine, FretboardView, lock-free queue
- Deliverable: Pedal-controlled chord changes with fretboard visualization

**Week 4: Multi-Layout + Pattern Generator + Library**
- NotationView, TABView, TimelineView
- PatternGenerator (4 components)
- 20-30 exercises (15-20 pattern-based, 5-10 explicit)
- Deliverable: Complete MVP with all visualization modes

## Testing Strategy

**Unit Tests:**
- Musical time conversions
- Pattern generation (all keys, all pattern types)
- Position mapping (fret/finger constraints)
- Quantization logic

**Integration Tests:**
- Audio engine lifecycle
- Lock-free queue (Thread Sanitizer)
- Audio-visual synchronization

**Manual Testing:**
- Latency measurement on real hardware
- MIDI device compatibility
- Canvas rendering performance (60 FPS)

## Development Commands

*To be added as Xcode project is set up*

Future sections:
- Build commands
- Test commands
- Dependency management (SPM)
- Code signing

## Important Notes for Implementation

1. **Never allocate on audio thread** - Use lock-free patterns exclusively
2. **Test with Thread Sanitizer** - Audio threading bugs are subtle
3. **Profile early** - Measure latency on real hardware (not simulator)
4. **Read ADRs first** - All major decisions are documented with rationale
5. **Follow roadmap sequence** - Each week builds on previous foundation
