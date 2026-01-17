# ADR-006: Full Arrangement Exercise Model

**Date:** 2026-01-17
**Status:** Accepted

## Context

Exercise data model could be:
1. Chords only (simple)
2. Chords + melody (moderate)
3. Full arrangement with melody, chords, bass, drums (complex)

## Decision

Store **full arrangement** (melody, chords, bass line, drums) in exercise JSON.

## Rationale

### Why Full Arrangement?
- **Rich Visualization:** Can show what backing track is playing
- **Educational:** Students understand complete musical context
- **Future-Proof:** Enables advanced features (part muting, arrangement view)
- **Flexibility:** Can display or hide parts as needed

### Why Not Simpler?
- Chords-only limits visualization options
- Cannot show what bass is doing
- Students lose musical context

## Implementation

```json
{
  "chords": [...],
  "melody": [...],
  "bassLine": [
    {"note": "C2", "startBeat": 0, "duration": 0.5},
    {"note": "E2", "startBeat": 0.5, "duration": 0.5}
  ],
  "drums": {
    "kick": [0, 2, 4, 6],
    "snare": [1, 3, 5, 7],
    "hihat": [0, 0.5, 1, 1.5, ...]
  }
}
```

## Consequences

### Positive
- ✅ Rich visualization across all views
- ✅ Educational value (see full arrangement)
- ✅ Future-proof for advanced features
- ✅ Can toggle part visibility

### Negative
- ❌ More complex JSON authoring
- ❌ Larger file sizes
- ❌ More parsing/validation needed

### Mitigation
- Phase 2 visual editor eliminates manual JSON
- Validation catches errors early
- File sizes still reasonable (< 100KB per exercise)

## References
- [ADR-004: JSON Exercise Storage](ADR-004-json-exercise-storage.md)
- [Visualization Architecture](../architecture/visualization-architecture.md)

## Notes
Complexity is worth the educational and visualization benefits.
