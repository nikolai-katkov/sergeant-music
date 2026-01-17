# ADR-005: SwiftUI Canvas for Rendering

**Date:** 2026-01-17
**Status:** Accepted

## Context

Need custom rendering for fretboard, notation, TAB, and timeline. Options: SwiftUI Canvas + Core Graphics, Metal, or UIKit drawing.

## Decision

Use **SwiftUI Canvas + Core Graphics** for all custom rendering.

## Rationale

### Why Canvas?
- **SwiftUI Integration:** Native to SwiftUI, no bridging
- **Performance:** Sufficient for 2D rendering at 60 FPS
- **Simplicity:** Declarative API, easier than Metal
- **Core Graphics:** Mature, well-documented drawing API
- **Flexibility:** Full control over rendering

### Why Not Metal?
- **Overkill:** GPU acceleration not needed for 2D notation
- **Complexity:** Shader programming steeper learning curve
- **iOS-Only:** Core Graphics more portable (macOS)

### Why Not UIKit?
- **Legacy:** Moving away from UIKit
- **Bridging:** Requires UIViewRepresentable wrapper
- **Less Declarative:** Imperative drawing code

## Implementation

```swift
struct FretboardView: View {
    var body: some View {
        Canvas { context, size in
            // Core Graphics drawing
            drawFretboard(context, size)
            drawNotes(context, notes)
        }
    }
}
```

## Consequences

### Positive
- ✅ Clean SwiftUI integration
- ✅ 60 FPS performance achievable
- ✅ Lower learning curve than Metal
- ✅ Mature Core Graphics API

### Negative
- ❌ CPU rendering (not GPU)
- ❌ May need Metal for 3D fretboard (future)
- ❌ Limited to 2D transformations

### Mitigation
- Optimize Canvas drawing (cache, dirty regions)
- Profile with Instruments
- Consider Metal for Phase 3 3D features

## Performance Targets

- 60 FPS during playback
- < 16ms per frame rendering
- Smooth animations

## References
- [Visualization Architecture](../architecture/visualization-architecture.md)
- SwiftUI Canvas Documentation

## Notes
Canvas is perfect for 2D notation. Metal remains option for 3D features.
