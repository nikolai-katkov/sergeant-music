# Visualization Architecture

## Overview

SergeantMusic provides real-time visualization of exercises across four different modes: Fretboard, Notation (sheet music), TAB (tablature), and Timeline (chord blocks). This document details the architecture for rendering these visualizations with sample-accurate synchronization to the audio engine.

## Core Requirements

- **60 FPS Performance:** Smooth animation during playback
- **Audio-Visual Sync:** < 50ms perceived latency
- **Multiple View Modes:** Fretboard, Notation, TAB, Timeline
- **Lookahead Display:** Show upcoming notes (1-2 bars ahead)
- **Theory Overlays:** Intervals, scale degrees, chord tones (Alpha Jams style)
- **Per-Exercise Configuration:** Some exercises may restrict certain views

## Technology Stack

### SwiftUI Canvas + Core Graphics
- **Canvas:** SwiftUI's high-performance drawing API
- **Core Graphics:** Low-level 2D rendering
- **Why not Metal?** Sufficient for 2D rendering, easier to learn, better SwiftUI integration

### Key Trade-offs
- **CPU Rendering:** Canvas uses CPU, not GPU
- **Acceptable:** For 2D notation at 60 FPS
- **Future:** Can migrate to Metal for 3D fretboard if needed

## Visualization Subsystem Architecture

```
┌─────────────────────────────────────────────────────────┐
│               Visualization Subsystem                    │
│                   (Main Thread)                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         PlaybackCursor (Shared)                   │  │
│  │  - Sample time → Screen position                  │  │
│  │  - Lookahead calculations                         │  │
│  │  - Beat → Pixel conversion                        │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│       ┌───────────┴───────────┬──────────────┬────────┐│
│       │                       │              │        ││
│  ┌────┴────────┐  ┌──────────┴──┐  ┌────────┴───┐  ┌┴┴
│  │ Fretboard   │  │  Notation   │  │    TAB     │  │Ti│
│  │ Renderer    │  │  Renderer   │  │  Renderer  │  │Re│
│  └─────────────┘  └─────────────┘  └────────────┘  └──┘
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │     View-Specific ViewModels                      │  │
│  │  - FretboardViewModel                             │  │
│  │  - NotationViewModel                              │  │
│  │  - TABViewModel                                   │  │
│  │  - TimelineViewModel                              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↑
                 PlaybackState Events
                           │
                 PracticeCoordinator
```

## Core Visualization Pattern

### PlaybackCursor: The Shared Foundation

**Responsibility:** Convert audio time to screen coordinates for all views.

**File:** `/Rendering/PlaybackCursor.swift`

```swift
class PlaybackCursor {
    private let musicalClock: MusicalClock
    private let sampleRate: Double = 44100

    // Shared configuration
    var pixelsPerBeat: CGFloat = 100
    var screenWidth: CGFloat = 0

    // MARK: - Core Conversions

    /// Convert beat to screen X position
    func beatToScreenPosition(_ beat: Double) -> CGFloat {
        return CGFloat(beat) * pixelsPerBeat
    }

    /// Convert screen X position to beat
    func screenPositionToBeat(_ position: CGFloat) -> Double {
        return Double(position / pixelsPerBeat)
    }

    /// Convert sample time to screen position
    func sampleTimeToScreenPosition(_ sampleTime: Int64) -> CGFloat {
        let beat = musicalClock.sampleTimeToBeat(sampleTime)
        return beatToScreenPosition(beat)
    }

    // MARK: - Lookahead

    /// Get notes in upcoming range (for smooth rendering)
    func upcomingNotes(from currentBeat: Double,
                      lookahead: Double = 2.0,
                      in exercise: Exercise) -> [NoteEvent] {
        let endBeat = currentBeat + lookahead

        return exercise.melody.filter { note in
            note.startBeat >= currentBeat && note.startBeat < endBeat
        }
    }

    // MARK: - Visible Range

    /// Calculate visible beat range for current scroll position
    func visibleRange(scrollOffset: CGFloat, screenWidth: CGFloat) -> ClosedRange<Double> {
        let startBeat = screenPositionToBeat(scrollOffset)
        let endBeat = screenPositionToBeat(scrollOffset + screenWidth)

        return startBeat...endBeat
    }
}
```

## Visualization Mode 1: Fretboard

### Design Goals
- Show notes lighting up as they should be played
- Display chord diagrams
- Theory overlay with intervals/scale degrees
- Alpha Jams-style fingering hints

### FretboardRenderer

**File:** `/Rendering/FretboardRenderer.swift`

```swift
struct FretboardRenderer {
    let layout: FretboardLayout
    let theoryMode: TheoryOverlayMode

    func render(in context: GraphicsContext,
                size: CGSize,
                notes: [FretboardNote],
                highlightedNotes: [FretboardNote]) {
        // Draw fretboard base
        drawFretboard(in: context, size: size)

        // Draw fret markers
        drawFretMarkers(in: context, size: size)

        // Draw strings
        drawStrings(in: context, size: size)

        // Draw frets
        drawFrets(in: context, size: size)

        // Draw notes
        for note in notes {
            drawNote(note, in: context, highlighted: false)
        }

        // Draw highlighted notes (current playback)
        for note in highlightedNotes {
            drawNote(note, in: context, highlighted: true)
        }

        // Draw theory overlay
        if theoryMode != .hidden {
            drawTheoryOverlay(in: context, notes: notes + highlightedNotes)
        }
    }

    private func drawFretboard(in context: GraphicsContext, size: CGSize) {
        // Fretboard background (wood texture or solid color)
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(.brown.opacity(0.3)))
    }

    private func drawStrings(in: GraphicsContext, size: CGSize) {
        let stringCount = 6
        let stringSpacing = size.height / CGFloat(stringCount + 1)

        for i in 1...stringCount {
            let y = stringSpacing * CGFloat(i)
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.gray), lineWidth: 2)
        }
    }

    private func drawFrets(in: GraphicsContext, size: CGSize) {
        let fretCount = 15
        let fretSpacing = size.width / CGFloat(fretCount)

        for i in 0...fretCount {
            let x = CGFloat(i) * fretSpacing
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(.gray), lineWidth: 3)
        }
    }

    private func drawNote(_ note: FretboardNote,
                         in context: GraphicsContext,
                         highlighted: Bool) {
        let position = layout.screenPosition(for: note)
        let radius: CGFloat = highlighted ? 20 : 15
        let color: Color = highlighted ? .blue : .gray.opacity(0.5)

        // Draw circle
        let circle = Circle()
            .path(in: CGRect(x: position.x - radius,
                           y: position.y - radius,
                           width: radius * 2,
                           height: radius * 2))

        context.fill(circle, with: .color(color))

        // Draw label
        if let label = noteLabel(for: note) {
            let text = Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            context.draw(text, at: position)
        }
    }

    private func drawTheoryOverlay(in context: GraphicsContext,
                                   notes: [FretboardNote]) {
        for note in notes {
            let position = layout.screenPosition(for: note)
            let label = theoryLabel(for: note, mode: theoryMode)

            // Draw theory label below note
            let labelPosition = CGPoint(x: position.x, y: position.y + 30)
            let text = Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            context.draw(text, at: labelPosition)
        }
    }

    private func noteLabel(for note: FretboardNote) -> String? {
        switch theoryMode {
        case .noteNames:
            return note.noteName
        case .intervals:
            return note.interval
        case .scaleDegrees:
            return note.scaleDegree
        case .hidden:
            return nil
        }
    }

    private func theoryLabel(for note: FretboardNote, mode: TheoryOverlayMode) -> String {
        // Alpha Jams style: show fingering hints, scale info
        switch mode {
        case .intervals:
            return note.intervalFromRoot.description
        case .scaleDegrees:
            return "Scale deg: \(note.degreeInScale)"
        default:
            return ""
        }
    }
}

struct FretboardNote {
    let string: Int // 1-6 (high E to low E)
    let fret: Int   // 0-15
    let noteName: String
    let midiNumber: Int
    let interval: String?
    let scaleDegree: String?
    let intervalFromRoot: Interval
    let degreeInScale: Int
}

struct FretboardLayout {
    let stringCount: Int = 6
    let fretCount: Int = 15
    let tuning: [Int] = [64, 59, 55, 50, 45, 40] // Standard tuning (EADGBE)

    func position(for note: Note) -> FretboardNote? {
        // Find note on fretboard
        for string in 0..<stringCount {
            let openString = tuning[string]

            for fret in 0...fretCount {
                let fretNote = openString + fret

                if fretNote == note.midiNumber {
                    return FretboardNote(
                        string: string + 1,
                        fret: fret,
                        noteName: note.name,
                        midiNumber: note.midiNumber,
                        interval: nil,
                        scaleDegree: nil,
                        intervalFromRoot: .unison,
                        degreeInScale: 1
                    )
                }
            }
        }

        return nil
    }

    func screenPosition(for note: FretboardNote) -> CGPoint {
        // Convert string/fret to screen coordinates
        // This depends on view size, calculated in View
        return CGPoint.zero // Placeholder
    }
}
```

### FretboardView

**File:** `/Features/Fretboard/Views/FretboardView.swift`

```swift
struct FretboardView: View {
    @ObservedObject var viewModel: FretboardViewModel

    var body: some View {
        Canvas { context, size in
            let renderer = FretboardRenderer(
                layout: viewModel.layout,
                theoryMode: viewModel.theoryOverlay
            )

            renderer.render(
                in: context,
                size: size,
                notes: viewModel.visibleNotes,
                highlightedNotes: viewModel.highlightedNotes
            )
        }
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.toggleTheoryOverlay()
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }
}
```

## Visualization Mode 2: Notation (Sheet Music)

### Design Goals
- Traditional staff notation
- Scrolling cursor (MuseScore style)
- TAB below staff (optional)
- Measure boundaries clearly marked

### NotationRenderer

**File:** `/Rendering/NotationRenderer.swift`

```swift
struct NotationRenderer {
    let staffHeight: CGFloat = 100
    let lineSpacing: CGFloat = 8

    func render(in context: GraphicsContext,
                size: CGSize,
                notes: [NoteEvent],
                cursorPosition: Double,
                visibleRange: ClosedRange<Double>,
                playbackCursor: PlaybackCursor) {
        // Draw staff lines
        drawStaff(in: context, size: size)

        // Draw measure lines
        drawMeasureLines(in: context, size: size, visibleRange: visibleRange, cursor: playbackCursor)

        // Draw notes
        for note in notes where visibleRange.contains(note.startBeat) {
            drawNote(note, in: context, cursor: playbackCursor)
        }

        // Draw playback cursor
        drawPlaybackCursor(in: context, size: size, position: cursorPosition, cursor: playbackCursor)
    }

    private func drawStaff(in context: GraphicsContext, size: CGSize) {
        // Draw 5 staff lines
        for i in 0..<5 {
            let y = CGFloat(i) * lineSpacing + 50
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.black), lineWidth: 1)
        }

        // Draw treble clef
        drawTrebleClef(in: context, at: CGPoint(x: 10, y: 50))
    }

    private func drawNote(_ note: NoteEvent,
                         in context: GraphicsContext,
                         cursor: PlaybackCursor) {
        let x = cursor.beatToScreenPosition(note.startBeat)
        let y = yPosition(for: note.pitch)

        // Draw note head
        let noteHead = Circle()
            .path(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))

        context.fill(noteHead, with: .color(.black))

        // Draw stem
        let stem = Path { p in
            p.move(to: CGPoint(x: x + 5, y: y))
            p.addLine(to: CGPoint(x: x + 5, y: y - 30))
        }
        context.stroke(stem, with: .color(.black), lineWidth: 1.5)

        // Draw ledger lines if needed
        drawLedgerLines(for: note, at: CGPoint(x: x, y: y), in: context)
    }

    private func drawPlaybackCursor(in context: GraphicsContext,
                                    size: CGSize,
                                    position: Double,
                                    cursor: PlaybackCursor) {
        let x = cursor.beatToScreenPosition(position)

        let path = Path { p in
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: size.height))
        }

        context.stroke(path, with: .color(.red), lineWidth: 2)
    }

    private func yPosition(for pitch: String) -> CGFloat {
        // Convert pitch (e.g., "C4") to staff position
        // This is a simplified version
        let pitchMap: [String: CGFloat] = [
            "C4": 90,
            "D4": 82,
            "E4": 74,
            "F4": 66,
            "G4": 58,
            "A4": 50,
            "B4": 42,
            "C5": 34
        ]

        return pitchMap[pitch] ?? 50
    }

    private func drawMeasureLines(in context: GraphicsContext,
                                  size: CGSize,
                                  visibleRange: ClosedRange<Double>,
                                  cursor: PlaybackCursor) {
        // Draw measure lines every 4 beats
        let firstMeasure = Int(visibleRange.lowerBound / 4)
        let lastMeasure = Int(visibleRange.upperBound / 4) + 1

        for measure in firstMeasure...lastMeasure {
            let beat = Double(measure * 4)
            let x = cursor.beatToScreenPosition(beat)

            let path = Path { p in
                p.move(to: CGPoint(x: x, y: 30))
                p.addLine(to: CGPoint(x: x, y: 90))
            }

            context.stroke(path, with: .color(.black), lineWidth: 2)
        }
    }

    private func drawTrebleClef(in context: GraphicsContext, at position: CGPoint) {
        // Draw treble clef symbol (simplified)
        let text = Text("𝄞")
            .font(.system(size: 60))
            .foregroundColor(.black)

        context.draw(text, at: position)
    }

    private func drawLedgerLines(for note: NoteEvent,
                                 at position: CGPoint,
                                 in context: GraphicsContext) {
        // Draw ledger lines for notes outside the staff
        // Implementation depends on note pitch
    }
}
```

### NotationView

**File:** `/Features/Notation/Views/NotationView.swift`

```swift
struct NotationView: View {
    @ObservedObject var viewModel: NotationViewModel
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { context, size in
                let renderer = NotationRenderer()

                renderer.render(
                    in: context,
                    size: size,
                    notes: viewModel.notes,
                    cursorPosition: viewModel.cursorPosition,
                    visibleRange: viewModel.visibleRange,
                    playbackCursor: viewModel.playbackCursor
                )
            }
            .frame(height: 200)
            .frame(width: viewModel.totalWidth)
        }
        .onChange(of: viewModel.scrollOffset) { newOffset in
            // Auto-scroll to follow cursor
            scrollOffset = newOffset
        }
    }
}
```

## Visualization Mode 3: TAB (Tablature)

### Design Goals
- Guitar-specific notation
- 6 lines (one per string)
- Fret numbers
- Playback cursor

### TABRenderer

**File:** `/Rendering/TABRenderer.swift`

```swift
struct TABRenderer {
    let stringCount: Int = 6
    let lineSpacing: CGFloat = 12

    func render(in context: GraphicsContext,
                size: CGSize,
                notes: [TABNote],
                cursorPosition: Double,
                playbackCursor: PlaybackCursor) {
        // Draw TAB lines
        drawTABLines(in: context, size: size)

        // Draw "TAB" label
        drawTABLabel(in: context)

        // Draw fret numbers
        for note in notes {
            drawFretNumber(note, in: context, cursor: playbackCursor)
        }

        // Draw playback cursor
        let x = playbackCursor.beatToScreenPosition(cursorPosition)
        drawCursor(at: x, in: context, size: size)
    }

    private func drawTABLines(in context: GraphicsContext, size: CGSize) {
        for i in 0..<stringCount {
            let y = CGFloat(i) * lineSpacing + 50
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.black), lineWidth: 1)
        }
    }

    private func drawFretNumber(_ note: TABNote,
                               in context: GraphicsContext,
                               cursor: PlaybackCursor) {
        let x = cursor.beatToScreenPosition(note.startBeat)
        let y = CGFloat(note.string - 1) * lineSpacing + 50

        let text = Text("\(note.fret)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.black)

        context.draw(text, at: CGPoint(x: x, y: y))
    }

    private func drawTABLabel(in context: GraphicsContext) {
        let text = Text("TAB")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)

        context.draw(text, at: CGPoint(x: 10, y: 30))
    }

    private func drawCursor(at x: CGFloat,
                           in context: GraphicsContext,
                           size: CGSize) {
        let path = Path { p in
            p.move(to: CGPoint(x: x, y: 40))
            p.addLine(to: CGPoint(x: x, y: 50 + CGFloat(stringCount - 1) * lineSpacing))
        }

        context.stroke(path, with: .color(.red), lineWidth: 2)
    }
}

struct TABNote {
    let string: Int // 1-6
    let fret: Int
    let startBeat: Double
    let duration: Double
}
```

## Visualization Mode 4: Timeline (Chord Blocks)

### Design Goals
- iReal Pro style
- Chord blocks with measure boundaries
- Current chord highlighted
- Simple, clean interface

### TimelineRenderer

**File:** `/Rendering/TimelineRenderer.swift`

```swift
struct TimelineRenderer {
    let blockHeight: CGFloat = 60

    func render(in context: GraphicsContext,
                size: CGSize,
                chords: [ChordEvent],
                currentBeat: Double,
                playbackCursor: PlaybackCursor) {
        // Draw timeline background
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.1)))

        // Draw chord blocks
        for chord in chords {
            drawChordBlock(chord, in: context, currentBeat: currentBeat, cursor: playbackCursor)
        }

        // Draw beat markers
        drawBeatMarkers(in: context, size: size, cursor: playbackCursor)
    }

    private func drawChordBlock(_ chord: ChordEvent,
                               in context: GraphicsContext,
                               currentBeat: Double,
                               cursor: PlaybackCursor) {
        let x = cursor.beatToScreenPosition(chord.startBeat)
        let width = cursor.beatToScreenPosition(chord.duration)

        let isActive = currentBeat >= chord.startBeat && currentBeat < chord.startBeat + chord.duration

        let rect = CGRect(x: x, y: 10, width: width, height: blockHeight)
        let color: Color = isActive ? .blue : .gray.opacity(0.3)

        // Draw block
        context.fill(Path(rect), with: .color(color))
        context.stroke(Path(rect), with: .color(.black), lineWidth: 2)

        // Draw chord symbol
        let text = Text(chord.symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(isActive ? .white : .black)

        context.draw(text, at: CGPoint(x: x + width / 2, y: 40))
    }

    private func drawBeatMarkers(in context: GraphicsContext,
                                 size: CGSize,
                                 cursor: PlaybackCursor) {
        // Draw beat divisions
        for beat in stride(from: 0.0, to: 64.0, by: 1.0) {
            let x = cursor.beatToScreenPosition(beat)

            if Int(beat) % 4 == 0 {
                // Measure line
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.black), lineWidth: 2)
            } else {
                // Beat line
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 10))
                    p.addLine(to: CGPoint(x: x, y: 70))
                }
                context.stroke(path, with: .color(.gray), lineWidth: 1)
            }
        }
    }
}

struct ChordEvent {
    let symbol: String
    let startBeat: Double
    let duration: Double
    let notes: [Note]
}
```

## Performance Optimization

### Technique 1: Dirty Region Tracking

Only redraw changed areas:

```swift
class VisualizationCache {
    private var lastRenderedBeat: Double = 0
    private var cachedImage: UIImage?

    func needsRedraw(currentBeat: Double) -> Bool {
        return abs(currentBeat - lastRenderedBeat) > 0.1
    }

    func cache(image: UIImage, beat: Double) {
        cachedImage = image
        lastRenderedBeat = beat
    }
}
```

### Technique 2: Geometry Caching

Pre-calculate note positions:

```swift
class GeometryCache {
    private var notePositions: [String: CGPoint] = [:]

    func position(for note: Note, layout: FretboardLayout) -> CGPoint {
        let key = "\(note.midiNumber)"

        if let cached = notePositions[key] {
            return cached
        }

        let position = layout.calculatePosition(for: note)
        notePositions[key] = position
        return position
    }
}
```

### Technique 3: View Culling

Don't render off-screen elements:

```swift
func visibleNotes(in range: ClosedRange<Double>, notes: [NoteEvent]) -> [NoteEvent] {
    return notes.filter { note in
        note.startBeat >= range.lowerBound && note.startBeat <= range.upperBound
    }
}
```

### Technique 4: Batch Updates

Update at 60 Hz max, not every audio callback:

```swift
// Already implemented in PracticeCoordinator
Timer.publish(every: 0.016, on: .main, in: .common) // 60 Hz
```

## Audio-Visual Synchronization

### Challenge
Audio thread runs at ~44100 Hz, UI runs at 60 Hz. How to sync?

### Solution: Lookahead + Interpolation

1. **Audio Thread:** Publishes playback position via lock-free queue
2. **Main Thread (60 Hz):** Polls queue, updates ViewModels
3. **Views:** Render based on current position + lookahead

```swift
class NotationViewModel: ObservableObject {
    @Published var cursorPosition: Double = 0

    // Called every 16ms (60 Hz)
    func update(beat: Double) {
        // Smooth interpolation
        let delta = beat - cursorPosition
        cursorPosition += delta * 0.3 // Smooth catch-up
    }
}
```

## Testing Visualization

### Unit Tests
- Playback cursor calculations (beat → pixel)
- Note positioning (pitch → staff line)
- Visible range calculations

### Integration Tests
- Audio-visual sync latency measurement
- Canvas rendering performance (FPS)

### Manual Testing
- Visual inspection of sync
- Frame rate monitoring (Instruments)
- Test on older devices (iPhone 11)

## Next Steps

1. Implement PlaybackCursor
2. Implement FretboardRenderer + FretboardView
3. Implement NotationRenderer + NotationView
4. Implement TABRenderer + TABView
5. Implement TimelineRenderer + TimelineView
6. Profile and optimize Canvas performance
7. Test audio-visual sync

---

**Related Documents:**
- [Architecture Overview](architecture-overview.md)
- [State Management](state-management.md)
- [ADR-005: SwiftUI Canvas Rendering](../adr/ADR-005-swiftui-canvas-rendering.md)
- [ADR-007: Shared Playback Cursor](../adr/ADR-007-shared-playback-cursor.md)
