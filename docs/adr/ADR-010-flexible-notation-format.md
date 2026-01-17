# ADR-010: Flexible Notation Format

**Date:** 2026-01-17
**Status:** Accepted

## Context

Melody notes in exercises could be specified as:
1. Absolute pitch (C4, E4, G4)
2. Relative scale degrees (1, 3, 5)
3. Both (dual representation)

## Decision

Support **both absolute pitch and relative scale degrees** in exercise JSON format.

## Rationale

### Why Both?
- **Flexibility:** Authors choose what makes sense
- **Transposition:** Scale degrees enable key changes
- **Education:** Can show both representations
- **Different Uses:**
  - Absolute: Specific melodies (songs)
  - Relative: Theory exercises (scale patterns)

### Use Cases

**Absolute Pitch:**
```json
{
  "melody": [
    {"pitch": "C4", "startBeat": 0, "duration": 1},
    {"pitch": "E4", "startBeat": 1, "duration": 1}
  ]
}
```

**Relative Scale Degrees:**
```json
{
  "melody": [
    {"scaleDegree": 1, "startBeat": 0, "duration": 1},
    {"scaleDegree": 3, "startBeat": 1, "duration": 1}
  ],
  "key": "C"
}
```

**Both (Redundant but Clear):**
```json
{
  "melody": [
    {"pitch": "C4", "scaleDegree": 1, "startBeat": 0, "duration": 1}
  ]
}
```

## Implementation

```swift
struct NoteEvent: Codable {
    let pitch: String?          // e.g., "C4"
    let scaleDegree: Int?       // e.g., 1
    let startBeat: Double
    let duration: Double

    func resolve(in key: String) -> Note {
        if let pitch = pitch {
            return Note(pitch: pitch)
        } else if let degree = scaleDegree {
            return Note(degree: degree, key: key)
        } else {
            fatalError("Must specify either pitch or scaleDegree")
        }
    }
}
```

## Consequences

### Positive
- ✅ Flexibility for exercise authors
- ✅ Easy transposition (scale degrees)
- ✅ Clear melodies (absolute pitch)
- ✅ Educational (can show both)

### Negative
- ❌ More complex parser
- ❌ Validation must check both
- ❌ Potential confusion (which to use?)

### Mitigation
- Clear documentation on when to use each
- Validation ensures at least one is present
- Default to scale degrees for theory exercises
- Use absolute pitch for songs/melodies

## Validation Rules

1. Must have either `pitch` OR `scaleDegree` (not neither)
2. Can have both (redundant but valid)
3. If `scaleDegree`, must have `key` in exercise
4. `pitch` must be valid note name (A0-C8)
5. `scaleDegree` must be 1-7 (or 1-12 for chromatic)

## References
- [ADR-004: JSON Exercise Storage](ADR-004-json-exercise-storage.md)
- [ADR-006: Full Arrangement Model](ADR-006-full-arrangement-exercise-model.md)

## Notes
Flexibility is valuable here. Authors will naturally gravitate to what works for their use case.
