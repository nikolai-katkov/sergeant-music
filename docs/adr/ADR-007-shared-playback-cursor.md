# ADR-007: Shared Playback Cursor

**Date:** 2026-01-17
**Status:** Accepted

## Context

Four visualization modes (Fretboard, Notation, TAB, Timeline) all need:
- Convert beat position → screen coordinates
- Calculate visible range
- Determine upcoming notes (lookahead)

Options: Duplicate logic in each view, or share common cursor service.

## Decision

Create a **shared PlaybackCursor service** that all views use for position calculations.

## Rationale

### Why Shared?
- **DRY:** Single implementation of beat → pixel conversion
- **Consistency:** All views use same timing calculations
- **Maintainability:** Bug fixes apply to all views
- **Testability:** Test once, use everywhere
- **Performance:** Can optimize in one place

### Why Not Per-View?
- Code duplication
- Inconsistent timing between views
- More bugs, more maintenance

## Implementation

```swift
class PlaybackCursor {
    var pixelsPerBeat: CGFloat = 100

    func beatToScreenPosition(_ beat: Double) -> CGFloat {
        return CGFloat(beat) * pixelsPerBeat
    }

    func screenPositionToBeat(_ position: CGFloat) -> Double {
        return Double(position / pixelsPerBeat)
    }

    func upcomingNotes(from beat: Double, lookahead: Double) -> [Note] {
        // Shared lookahead logic
    }
}
```

## Consequences

### Positive
- ✅ No code duplication
- ✅ Consistent timing across views
- ✅ Single source of truth
- ✅ Easy to unit test
- ✅ Centralized lookahead logic

### Negative
- ❌ All views depend on same service
- ❌ Changes affect all views
- ❌ Slightly less flexible per-view

### Mitigation
- Design API carefully upfront
- Make extensible (view-specific overrides if needed)
- Comprehensive unit tests

## References
- [Visualization Architecture](../architecture/visualization-architecture.md)

## Notes
This pattern is used by MuseScore, Sibelius, and other notation software.
