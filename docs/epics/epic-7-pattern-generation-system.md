# Epic 7: Pattern Generation System

**Priority:** High (Phase 1 MVP - Week 4)
**Status:** Planned
**Estimated Effort:** 3-4 days

## Overview

Implement algorithmic pattern generation system enabling infinite exercise variations from single pattern definitions. This system generates scale patterns, arpeggios, and interval exercises with position constraints, enabling practice in all 12 keys from one pattern definition.

## Business Value

**For Users:**
- Practice same exercise in any key (random key selection)
- Infinite variations from pattern library (inversions, directions, rhythms)
- Position-specific exercises (classic, position 2, etc.)
- Exponentially more content without manual authoring
- Systematic skill development (scales → arpeggios → intervals)

**For Development:**
- 15-20 pattern definitions → thousands of variations
- Reduces manual exercise authoring workload
- Future-proof for advanced features (transposition, customization)

## Technical Scope

### Components

1. **PatternGenerator** - Orchestration
2. **ScaleEngine** - Scale note generation
3. **PositionMapper** - Fretboard position mapping
4. **SequenceBuilder** - Inversion/direction/rhythm variations
5. **PatternDefinition Model** - Pattern data structure

### Integration Points

- `ExerciseService` calls `PatternGenerator.generate()` for pattern-based exercises
- Generated `[NoteEvent]` fed into `EventSequencer`
- Compatible with all visualization modes (Fretboard, Notation, TAB, Timeline)

## User Stories

### US-E7-001: Generate Scale Pattern Exercise

```
As a guitar player
I want to practice major scale patterns in any key
So that I can develop scale fluency across the fretboard

Acceptance Criteria:
- Can load pattern-based exercise (e.g., "Major Scale - 3 Notes Per String - Position 1")
- Pattern generates notes in specified key
- Notes respect position constraints (frets, fingers)
- Can regenerate same exercise in different key
- Generated notes displayed correctly in all views (fretboard, notation, TAB)

Technical Notes:
- ScaleEngine.notes(key: "F", scale: .major) → [F, G, A, Bb, C, D, E, F]
- PositionMapper.mapToFretboard(notes, position: classic) → [(string, fret, finger)]
- Respects 3 notes per string rule
```

---

### US-E7-002: Random Key Selection

```
As a guitar player
I want to practice the same exercise in random keys
So that I don't memorize finger patterns instead of music

Acceptance Criteria:
- Exercise with `allowRandomKey: true` can select random key
- User can tap "New Key" to regenerate in different key
- Generated exercise musically correct in all keys
- Key displayed in UI ("Currently practicing in: Db major")
- Same pattern structure maintained across keys

Technical Notes:
- PatternGenerator.generate(pattern, key: Keys.random())
- Keys.random() → one of 12 keys
- Pattern structure (intervals, sequences) identical, absolute pitches change
```

---

### US-E7-003: Generate Arpeggio Sequence with Inversions

```
As a guitar player
I want to practice 7th chord arpeggios with all inversions
So that I can play fluid arpeggios across the fretboard

Acceptance Criteria:
- Load arpeggio exercise (e.g., "Major 7th Arpeggios - Classic Position")
- Generates all diatonic 7th chords (Imaj7, IImin7, IIImin7, etc.)
- Each chord played in all inversions (root, 1st, 2nd, 3rd)
- Both ascending and descending sequences
- Position constraints enforced (classic fingering box)

Technical Notes:
- Pattern defines:
  - chordTypes: ["maj7", "min7", "min7", "maj7", "dom7", "min7", "min7b5"]
  - sequences: [
      {intervals: [1, 3, 5, 7], direction: "ascending"},
      {intervals: [3, 5, 7, 1], direction: "ascending"},
      {intervals: [5, 7, 1, 3], direction: "ascending"}
    ]
- SequenceBuilder creates note sequences for each inversion
- PositionMapper ensures notes fit in classic position (frets 1-4)
```

---

### US-E7-004: Position-Based Constraints

```
As a guitar player
I want exercises to stay within specific fretboard positions
So that I develop position-specific muscle memory

Acceptance Criteria:
- Pattern definition includes position constraints (startFret, endFret)
- Generated notes only use specified frets
- Finger map enforced (e.g., finger 1 for frets 1-2, finger 2 for fret 3)
- String rules respected (e.g., max 3 notes per string, exceptions for B string)
- Invalid patterns rejected with clear error message

Technical Notes:
- Position definition:
  ```json
  {
    "startFret": 1,
    "endFret": 4,
    "fingerMap": {"1": [1, 2], "2": [3], "3": [4]},
    "stringRules": {
      "default": {"maxNotes": 3},
      "exceptions": [
        {"string": 2, "maxNotes": 2, "condition": "adjacent_string_has_note_in_position"}
      ]
    }
  }
  ```
- PositionMapper.validate(notes, position) → throws if impossible
```

---

### US-E7-005: Rhythmic Variations

```
As a guitar player
I want to practice same pattern with different rhythms
So that I develop rhythmic flexibility

Acceptance Criteria:
- Pattern includes multiple rhythmic variations
- Can cycle through rhythms (upbeat → upbeat-downbeat → triplets)
- Rhythm applied consistently across entire exercise
- Metronome/backing track matches selected rhythm
- Rhythm displayed in notation view

Technical Notes:
- Pattern rhythmicPatterns:
  ```json
  [
    {"name": "upbeat", "noteDurations": [0.5, 0.5, 0.5, 0.5]},
    {"name": "upbeat-downbeat", "noteDurations": [0.5, 0.5, 1.0, 1.0]}
  ]
  ```
- SequenceBuilder.applyRhythm(notes, pattern) → sets startBeat, duration
```

---

### US-E7-006: Interval Pattern Generation

```
As a guitar player
I want to practice diatonic intervals (3rds, 4ths, 6ths)
So that I can develop intervallic hearing and technique

Acceptance Criteria:
- Load interval exercise (e.g., "Diatonic Thirds - Major Scale")
- Generates note pairs at specified interval
- Covers full scale range
- Both ascending and descending
- Position constraints respected

Technical Notes:
- Pattern type: "interval-pattern"
- ScaleEngine generates scale
- SequenceBuilder creates pairs: (scale[0], scale[2]), (scale[1], scale[3]), ...
- PositionMapper fits into position
```

---

## Technical Implementation

### Component: PatternGenerator

**Responsibility:** Orchestrate pattern-to-notes conversion

**Interface:**
```swift
class PatternGenerator {
    func generate(pattern: PatternDefinition, key: String) throws -> [NoteEvent]
}
```

**Algorithm:**
```swift
func generate(pattern: PatternDefinition, key: String) throws -> [NoteEvent] {
    // 1. Get scale notes
    let scale = try ScaleEngine.notes(for: key, scale: pattern.scale)

    // 2. Generate chords from scale (if arpeggio pattern)
    let chords = generateChords(scale: scale, chordTypes: pattern.chordTypes)

    // 3. For each chord, generate sequences
    var allNotes: [NoteEvent] = []
    for (index, chord) in chords.enumerated() {
        for sequence in pattern.sequences {
            let sequenceNotes = try SequenceBuilder.build(
                chord: chord,
                intervals: sequence.intervals,
                direction: sequence.direction
            )

            // 4. Map to fretboard position
            let mappedNotes = try PositionMapper.map(
                notes: sequenceNotes,
                position: pattern.position
            )

            // 5. Apply rhythm
            let timedNotes = SequenceBuilder.applyRhythm(
                notes: mappedNotes,
                pattern: pattern.rhythmicPatterns[0],
                startBeat: currentBeat
            )

            allNotes.append(contentsOf: timedNotes)
            currentBeat += calculateDuration(timedNotes)
        }
    }

    return allNotes
}
```

---

### Component: ScaleEngine

**Responsibility:** Generate scale notes in any key

**Interface:**
```swift
class ScaleEngine {
    static func notes(for key: String, scale: ScaleType) throws -> [Note]
}

enum ScaleType {
    case major
    case naturalMinor
    case harmonicMinor
    case melodicMinor
    // ... more scales
}
```

**Implementation:**
```swift
static func notes(for key: String, scale: ScaleType) throws -> [Note] {
    let root = try Note(name: key)
    let intervals = scale.intervals // e.g., major = [0, 2, 4, 5, 7, 9, 11]

    return intervals.map { semitones in
        root.transpose(by: semitones)
    }
}
```

---

### Component: PositionMapper

**Responsibility:** Map notes to fretboard with constraints

**Interface:**
```swift
class PositionMapper {
    static func map(notes: [Note], position: Position) throws -> [NoteEvent]
}

struct Position {
    let startFret: Int
    let endFret: Int
    let fingerMap: [Int: [Int]] // Finger → frets
    let stringRules: StringRules
}
```

**Algorithm:**
```swift
static func map(notes: [Note], position: Position) throws -> [NoteEvent] {
    var mappedNotes: [NoteEvent] = []
    var currentString = position.startString
    var notesOnString = 0

    for note in notes {
        // Find fret for note on current string
        guard let fret = findFret(note, string: currentString, position: position) else {
            throw PositionError.noteNotInPosition
        }

        // Check string rules
        let maxNotes = position.stringRules.maxNotes(for: currentString)
        if notesOnString >= maxNotes {
            currentString -= 1 // Move to next string
            notesOnString = 0
        }

        // Determine finger based on fret
        let finger = position.fingerMap.finger(for: fret)

        mappedNotes.append(NoteEvent(
            pitch: note,
            string: currentString,
            fret: fret,
            finger: finger
        ))

        notesOnString += 1
    }

    return mappedNotes
}
```

---

### Component: SequenceBuilder

**Responsibility:** Create note sequences (inversions, directions, rhythms)

**Interface:**
```swift
class SequenceBuilder {
    static func build(
        chord: Chord,
        intervals: [Int],
        direction: Direction
    ) throws -> [Note]

    static func applyRhythm(
        notes: [NoteEvent],
        pattern: RhythmicPattern,
        startBeat: Double
    ) -> [NoteEvent]
}

enum Direction {
    case ascending
    case descending
}
```

**Implementation:**
```swift
static func build(chord: Chord, intervals: [Int], direction: Direction) throws -> [Note] {
    let chordNotes = chord.notes(for: intervals) // e.g., [1, 3, 5, 7] → [C, E, G, B]
    return direction == .ascending ? chordNotes : chordNotes.reversed()
}

static func applyRhythm(notes: [NoteEvent], pattern: RhythmicPattern, startBeat: Double) -> [NoteEvent] {
    var currentBeat = startBeat
    return notes.enumerated().map { index, note in
        let duration = pattern.noteDurations[index % pattern.noteDurations.count]
        let timedNote = note.with(startBeat: currentBeat, duration: duration)
        currentBeat += duration
        return timedNote
    }
}
```

---

## Data Model

### PatternDefinition

```swift
struct PatternDefinition: Codable {
    let type: PatternType
    let scale: ScaleType
    let chordTypes: [ChordType]?
    let rootDegrees: [Int]?
    let sequences: [Sequence]
    let rhythmicPatterns: [RhythmicPattern]

    enum PatternType: String, Codable {
        case arpeggioSequence = "arpeggio-sequence"
        case scalePattern = "scale-pattern"
        case intervalPattern = "interval-pattern"
        case chordProgression = "chord-progression"
    }
}

struct Sequence: Codable {
    let name: String?
    let intervals: [Int]
    let direction: Direction
    let octaveRange: Int?
}

struct RhythmicPattern: Codable {
    let name: String
    let noteDurations: [Double] // In beats
    let description: String?
}

struct Position: Codable {
    let name: String
    let startFret: Int
    let endFret: Int
    let fingerMap: [String: [Int]] // JSON uses string keys
    let startString: Int
    let endString: Int
    let stringRules: StringRules
}

struct StringRules: Codable {
    let defaultRule: StringRule
    let exceptions: [StringRuleException]?

    struct StringRule: Codable {
        let maxNotes: Int
        let preferredNotes: Int?
    }

    struct StringRuleException: Codable {
        let string: Int
        let maxNotes: Int
        let condition: String?
        let adjacentString: Int?
        let reason: String?
    }
}
```

---

## Integration with ExerciseService

```swift
class ExerciseService {
    func loadExercise(id: String) throws -> Exercise {
        let json = try loadJSON(id)
        let exercise = try JSONDecoder().decode(Exercise.self, from: json)

        switch exercise.exerciseType {
        case .pattern:
            // Generate notes from pattern
            guard let pattern = exercise.pattern else {
                throw ExerciseError.missingPattern
            }

            let key = exercise.allowRandomKey ? Keys.random() : exercise.key
            let generatedNotes = try PatternGenerator.generate(pattern: pattern, key: key)

            // Return exercise with generated notes
            return exercise.with(melody: generatedNotes, key: key)

        case .explicit:
            // Notes already in JSON
            return exercise

        case .hybrid:
            // Generate pattern notes, merge with explicit chords
            let patternNotes = try PatternGenerator.generate(pattern: exercise.pattern!, key: exercise.key)
            return exercise.with(melody: patternNotes)
        }
    }
}
```

---

## Testing Strategy

### Unit Tests

1. **ScaleEngine Tests:**
   - Test all scale types (major, minor, harmonic, melodic)
   - Test all 12 keys
   - Verify correct intervals

2. **PositionMapper Tests:**
   - Test position constraints (frets, fingers)
   - Test string rules (max notes, exceptions)
   - Test invalid patterns throw errors

3. **SequenceBuilder Tests:**
   - Test inversions (root, 1st, 2nd, 3rd)
   - Test directions (ascending, descending)
   - Test rhythmic patterns applied correctly

4. **PatternGenerator Integration Tests:**
   - Test full pattern → notes pipeline
   - Test all pattern types (scales, arpeggios, intervals)
   - Test random key generation
   - Verify generated notes match position constraints

### Manual Validation

- Load pattern-based exercises in app
- Verify notes displayed correctly in all views
- Check fingering annotations match position rules
- Test random key regeneration
- Verify all sequences sound musically correct

---

## Performance Considerations

- **Pre-generation:** Generate exercises on background thread when loading library
- **Caching:** Cache generated exercises by (patternId, key) to avoid regeneration
- **Lazy Loading:** Only generate exercises when selected by user
- **Validation:** Validate patterns at parse time, not generation time

---

## Error Handling

```swift
enum PatternGenerationError: Error {
    case invalidScale(String)
    case invalidKey(String)
    case noteNotInPosition(Note, Position)
    case impossibleSequence(String)
    case invalidChordType(String)
}
```

All errors should provide clear messages for debugging invalid pattern definitions.

---

## Success Criteria

- [ ] All 4 components implemented (PatternGenerator, ScaleEngine, PositionMapper, SequenceBuilder)
- [ ] PatternDefinition model matches JSON schema
- [ ] ExerciseService integrates pattern generation
- [ ] 15-20 pattern-based exercises authored and tested
- [ ] Random key selection works for all patterns
- [ ] All unit tests pass
- [ ] Generated exercises display correctly in all views (Fretboard, Notation, TAB, Timeline)
- [ ] Position constraints enforced (notes stay in fingering box)
- [ ] Performance acceptable (< 100ms to generate complex pattern)

---

## Dependencies

- **Blocks:** Epic 6 (Exercise Library) - needs Exercise model and ExerciseService
- **Blocked By:** None
- **Related:** Epic 1 (Audio Engine), Epic 5 (Visualization)

---

## Future Enhancements (Phase 2+)

- User-customizable patterns (visual pattern editor)
- More scale types (modes, exotic scales)
- More complex rhythmic patterns (triplets, swing feel)
- Multi-position patterns (crossing positions)
- Automatic difficulty progression
- Pattern variations (skip patterns, wider intervals)

---

**Related Documents:**
- [ADR-011: Algorithmic Pattern Generator](../adr/ADR-011-algorithmic-pattern-generator.md)
- [Exercise JSON Schema](../exercise-json-schema.md)
- [Roadmap - Week 4](../roadmap.md#week-4-multi-layout-visualization--pattern-generator--exercise-library)
