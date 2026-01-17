# ADR-004: JSON for Exercise Storage

**Date:** 2026-01-17
**Status:** Accepted

## Context

Need to store exercise data including chords, melody, tempo, groove style, and metadata. Options: JSON files, SQLite, Core Data, CloudKit, or custom binary format.

## Decision

Use **local JSON files** with Swift Codable for Phase 1 MVP.

## Rationale

### Why JSON?
- **Simple:** Text-based, human-readable, easy to debug
- **Version Control:** Can track changes in git
- **No Backend:** No server dependencies for MVP
- **Standard:** Well-supported by Swift (Codable)
- **Portable:** Easy to export/share
- **Editable:** Can hand-edit during development

### Why Local (Not Cloud)?
- **MVP Focus:** Sync not needed for Phase 1
- **Offline First:** Works without network
- **Simple:** No authentication, no server costs
- **Fast:** Instant loading from bundle

## Implementation

### File Structure
```
Resources/Exercises/
  beginner/
    exercise-001-c-major-triads.json
    exercise-002-g-major-progression.json
  intermediate/
    exercise-010-blues-in-e.json
  advanced/
    exercise-020-jazz-ii-v-i.json
```

### Schema Example
```json
{
  "id": "exercise-001",
  "title": "Basic I-IV-V in C",
  "key": "C",
  "tempo": 120,
  "timeSignature": "4/4",
  "grooveStyle": "rock-8th",
  "difficulty": "beginner",
  "category": "chord-progressions",
  "allowedViews": ["fretboard", "timeline", "notation"],
  "chords": [
    {
      "symbol": "C",
      "voicing": [0, 2, 2, 0, 1, 0],
      "startBeat": 0,
      "duration": 4
    }
  ],
  "melody": [
    {
      "pitch": "E4",
      "scaleDegree": 3,
      "startBeat": 0,
      "duration": 1
    }
  ]
}
```

## Consequences

### Positive
- ✅ Fast development (no database setup)
- ✅ Easy debugging (readable format)
- ✅ Version controllable
- ✅ Simple loading with Codable
- ✅ No backend complexity

### Negative
- ❌ No built-in sync
- ❌ Manual JSON editing required (Phase 1)
- ❌ No query capabilities
- ❌ File size grows linearly

### Mitigation
- Build visual editor in Phase 2
- Validate JSON on load (clear error messages)
- Create JSON schema for validation
- Provide example exercises as templates

## Migration Path

### Phase 2: CloudKit
When sync is needed:
1. Keep JSON as serialization format
2. Store in CloudKit as CKAsset
3. Sync changes via CloudKit
4. Local JSON cache for offline

### Alternative: SQLite
If query performance becomes important:
1. Parse JSON into SQLite on first launch
2. Use JSON for import/export
3. SQLite for runtime queries

## Validation

### JSON Schema
Create JSON Schema for validation:
- Required fields
- Type checking
- Value constraints (tempo range, etc.)
- Enum validation (difficulty, category)

### Runtime Validation
```swift
struct Exercise: Codable {
    let id: String
    let title: String
    let tempo: Double

    func validate() throws {
        guard tempo >= 40 && tempo <= 240 else {
            throw ExerciseError.invalidTempo
        }
        guard !chords.isEmpty else {
            throw ExerciseError.noChords
        }
    }
}
```

## References
- [Exercise JSON Schema](../schemas/exercise-schema.json)
- Swift Codable Documentation

## Review Trigger
Migrate from JSON if:
- Need cloud sync
- File sizes exceed 1MB per exercise
- Need complex queries
- Manual editing becomes bottleneck

## Notes
JSON is perfect for MVP. Visual editor in Phase 2 will eliminate manual editing pain.
