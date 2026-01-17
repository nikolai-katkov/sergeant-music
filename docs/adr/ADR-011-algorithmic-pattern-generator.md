# ADR-011: Algorithmic Pattern Generator

**Date:** 2026-01-17
**Status:** Accepted
**Deciders:** Architecture team, Product owner

## Context

User example revealed that most exercises are **algorithmic patterns**:
- Scale patterns (all 7th chord arpeggios in F major)
- Position-based exercises (classic fingering, 1-4 frets)
- Pattern variations (1-3-5-7, 3-5-7-1, inversions, ascending/descending)
- **Random scale practice** (same exercise in any key)
- String/fingering constraints (3 notes per string, finger assignments)

Pre-computing all variations would require **thousands** of manually-written note sequences. This is not scalable.

## Decision

Implement **algorithmic pattern generator** in Phase 1 MVP that:
1. Generates note sequences from pattern definitions
2. Supports random scale selection
3. Respects fretboard position constraints
4. Handles pattern variations (inversions, directions, rhythms)
5. Co-exists with explicit note exercises (hybrid support)

## Rationale

### Why In Phase 1?
- **Core Feature:** Most exercises are algorithmic (not explicit notes)
- **Unique Value:** Random scale practice is key differentiator
- **Scalability:** One pattern definition → infinite variations
- **Educational:** Focus on patterns, not memorization
- **Practical:** Can't manually write thousands of variations

### Why Not Defer to Phase 2?
- Would severely limit MVP usefulness
- Manual exercise authoring would be bottleneck
- Random scale practice is essential for learning
- Pattern generation is what makes the app powerful

## Architecture

### Pattern Generator System

```
Exercise JSON (Pattern Definition)
    ↓
PatternGenerator.generate()
    ↓
Apply Scale (e.g., F major)
    ↓
Apply Position Constraints (frets 1-4)
    ↓
Apply String Rules (3 notes per string)
    ↓
Apply Sequence Variations (1-3-5-7, etc.)
    ↓
Apply Rhythmic Pattern (upbeat/downbeat)
    ↓
Generated Note Sequence (NoteEvent[])
    ↓
EventSequencer schedules
    ↓
Audio playback + Visualization
```

### Key Components

**New Files:**
- `/Core/PatternGeneration/PatternGenerator.swift` - Main generator
- `/Core/PatternGeneration/ScaleEngine.swift` - Scale note generation
- `/Core/PatternGeneration/PositionMapper.swift` - Fretboard position logic
- `/Core/PatternGeneration/SequenceBuilder.swift` - Pattern variations
- `/Core/Models/PatternDefinition.swift` - Pattern data model

## JSON Schema (Hybrid)

### Pattern-Based Exercise
```json
{
  "id": "pattern-001",
  "exerciseType": "pattern",
  "title": "7th Chord Arpeggios - Classic Position",
  "key": "F",
  "allowRandomKey": true,
  "tempo": 80,
  "grooveStyle": "metronome-only",

  "pattern": {
    "type": "arpeggio-sequence",
    "scale": "major",
    "chordTypes": ["maj7", "min7", "min7", "maj7", "dom7", "min7", "min7b5"],
    "rootDegrees": [1, 2, 3, 4, 5, 6, 7],

    "sequences": [
      {"intervals": [1, 3, 5, 7], "direction": "ascending"},
      {"intervals": [3, 5, 7, 1], "direction": "ascending"},
      {"intervals": [5, 7, 1, 3], "direction": "ascending"},
      {"intervals": [7, 1, 3, 5], "direction": "ascending"},
      {"intervals": [1, 3, 5, 7], "direction": "descending"},
      {"intervals": [3, 5, 7, 1], "direction": "descending"},
      {"intervals": [5, 7, 1, 3], "direction": "descending"}
    ],

    "rhythmicPatterns": ["upbeat", "upbeat-downbeat"]
  },

  "position": {
    "name": "classic",
    "startFret": 1,
    "endFret": 4,
    "fingerMap": {
      "1": [1, 2],
      "2": [3],
      "3": [4]
    },
    "stringRules": {
      "default": 3,
      "exceptions": [
        {
          "string": 2,
          "maxNotes": 2,
          "condition": "adjacent_string_has_note_in_box"
        }
      ]
    }
  }
}
```

### Explicit Note Exercise (Simple)
```json
{
  "id": "song-001",
  "exerciseType": "explicit",
  "title": "Simple Melody in C",
  "key": "C",
  "tempo": 120,
  "grooveStyle": "pop-ballad",

  "chords": [
    {"symbol": "C", "voicing": [0, 2, 2, 0, 1, 0], "startBeat": 0, "duration": 4}
  ],

  "melody": [
    {"pitch": "E4", "startBeat": 0, "duration": 1, "string": 2, "fret": 5}
  ]
}
```

## Implementation Plan

### Core Pattern Generator

```swift
class PatternGenerator {
    func generate(pattern: PatternDefinition, key: String) -> [NoteEvent] {
        // 1. Get scale notes
        let scale = ScaleEngine.notes(for: key, scale: pattern.scale)

        // 2. Generate chords from scale
        let chords = generateChords(scale, types: pattern.chordTypes, roots: pattern.rootDegrees)

        // 3. For each chord, generate sequences
        var allNotes: [NoteEvent] = []
        var currentBeat = 0.0

        for chord in chords {
            for sequence in pattern.sequences {
                let notes = generateSequence(
                    chord: chord,
                    intervals: sequence.intervals,
                    direction: sequence.direction,
                    position: pattern.position,
                    startBeat: currentBeat
                )
                allNotes.append(contentsOf: notes)
                currentBeat += Double(notes.count) * 0.5 // Assuming 8th notes
            }
        }

        return allNotes
    }

    private func generateSequence(
        chord: Chord,
        intervals: [Int],
        direction: Direction,
        position: FretboardPosition,
        startBeat: Double
    ) -> [NoteEvent] {
        // 1. Get chord tones
        let chordTones = chord.notes(for: intervals)

        // 2. Apply direction
        let orderedNotes = direction == .ascending ? chordTones : chordTones.reversed()

        // 3. Map to fretboard position
        let fretboardNotes = PositionMapper.map(
            notes: orderedNotes,
            to: position,
            respecting: position.stringRules
        )

        // 4. Convert to NoteEvents with timing
        return fretboardNotes.enumerated().map { index, note in
            NoteEvent(
                pitch: note.pitch,
                scaleDegree: note.scaleDegree,
                startBeat: startBeat + (Double(index) * 0.5),
                duration: 0.5,
                string: note.string,
                fret: note.fret,
                finger: note.finger
            )
        }
    }
}
```

### Position Mapper

```swift
class PositionMapper {
    static func map(
        notes: [Note],
        to position: FretboardPosition,
        respecting rules: StringRules
    ) -> [FretboardNote] {
        var result: [FretboardNote] = []
        var currentString = 6 // Start on low E
        var notesOnCurrentString = 0

        for note in notes {
            // Find note in position
            if let fretboardNote = findInPosition(note, position: position, string: currentString) {
                result.append(fretboardNote)
                notesOnCurrentString += 1

                // Check if need to move to next string
                let maxNotes = rules.maxNotes(for: currentString, given: result)
                if notesOnCurrentString >= maxNotes {
                    currentString -= 1
                    notesOnCurrentString = 0
                }
            }
        }

        return result
    }

    private static func findInPosition(
        _ note: Note,
        position: FretboardPosition,
        string: Int
    ) -> FretboardNote? {
        // Find note on specified string within fret range
        let tuning = standardTuning[string - 1]

        for fret in position.startFret...position.endFret {
            if tuning + fret == note.midiNumber {
                let finger = position.fingerMap.finger(for: fret)
                return FretboardNote(
                    note: note,
                    string: string,
                    fret: fret,
                    finger: finger
                )
            }
        }

        return nil
    }
}
```

### Random Scale Feature

```swift
class ExerciseService {
    func loadExercise(_ id: String, randomKey: Bool = false) throws -> GeneratedExercise {
        let definition = try loadPatternDefinition(id)

        // Random key if requested
        let key = randomKey ? randomMajorKey() : definition.key

        // Generate notes
        let notes = PatternGenerator.generate(pattern: definition, key: key)

        return GeneratedExercise(
            definition: definition,
            key: key,
            notes: notes
        )
    }

    private func randomMajorKey() -> String {
        let keys = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
        return keys.randomElement()!
    }
}
```

## Consequences

### Positive
- ✅ One pattern → infinite variations
- ✅ Random scale practice (essential for learning)
- ✅ Scalable (easy to add new patterns)
- ✅ DRY (no repeated note sequences)
- ✅ Flexible (modify pattern logic once)
- ✅ Educational (focus on patterns, not specific songs)

### Negative
- ❌ More complex implementation (~1 week additional development)
- ❌ Need sophisticated music theory engine
- ❌ Debugging harder (generated notes)
- ❌ JSON schema more complex

### Mitigation
- Start with simple patterns, add complexity incrementally
- Comprehensive unit tests for note generation
- Debug view showing generated notes
- Clear error messages for invalid patterns
- Hybrid approach: support explicit notes too

## Updated Timeline

### Week 4 Expanded (Now 1.5 Weeks)
- Pattern generator implementation
- Scale engine (major, minor, modes)
- Position mapper with string rules
- Sequence builder (variations, directions)
- Pattern-based JSON schema
- Generate 5-10 pattern definitions
- Also support explicit note exercises

**Trade-off:** MVP extends by ~3-4 days, but delivers much more value

## Pattern Library (Phase 1)

### 10-15 Pattern Definitions:
1. **Scale Patterns:**
   - 3-note-per-string scales (all positions)
   - 1-octave scales
   - 2-octave scales

2. **Arpeggio Patterns:**
   - Triad arpeggios (major, minor)
   - 7th chord arpeggios (maj7, min7, dom7)
   - All inversions

3. **Interval Patterns:**
   - 3rds, 4ths, 5ths, 6ths across scale
   - Diatonic intervals in all positions

4. **Chord Progression Patterns:**
   - I-IV-V with rhythm variations
   - ii-V-I in all keys
   - Blues progressions

**Each pattern × 12 keys × variations = thousands of practice exercises!**

## Exercise Types

### Pattern-Based
- Scales
- Arpeggios
- Intervals
- Technical exercises
- **Supports random key**

### Explicit-Based
- Songs
- Specific melodies
- Composed exercises
- **Fixed key**

### Hybrid
- Chord progression (explicit) + improvisation pattern (generated)

## Visualization Requirements

### Fretboard View Must Show:
1. **Current notes** (highlighted in real-time)
2. **Position box** (frets 1-4 outline)
3. **Upcoming notes** (lookahead, dimmed)
4. **Finger numbers** (1, 2, 3, 4 on each note)
5. **Toggleable overlays:**
   - Note names (F, A, C, E)
   - Scale degrees (1, 3, 5, 7)
   - Intervals (R, 3rd, 5th, 7th)
   - All simultaneously (user preference)

### Implementation
```swift
struct FretboardNote {
    let note: Note
    let string: Int
    let fret: Int
    let finger: Int          // NEW: 1-4
    let scaleDegree: Int     // NEW: 1-7
    let intervalFromRoot: Interval  // NEW: for overlay
    let isCurrentNote: Bool
    let isUpcomingNote: Bool
}

enum TheoryOverlayMode {
    case noteNames
    case scaleDegrees
    case intervals
    case all           // NEW: show all info
}
```

## References
- [ADR-006: Full Arrangement Model](ADR-006-full-arrangement-exercise-model.md)
- [ADR-009: Manual JSON Authoring](ADR-009-manual-json-authoring.md)
- [Visualization Architecture](../architecture/visualization-architecture.md)

## Review Trigger
Assess pattern generator success after Phase 1:
- Can generate all needed exercise types?
- Performance acceptable (< 100ms generation time)?
- User feedback on pattern quality?

## Notes
This decision significantly increases Phase 1 scope but delivers exponentially more value. The pattern generator is what makes SergeantMusic a professional learning tool, not just a chord progression player.
