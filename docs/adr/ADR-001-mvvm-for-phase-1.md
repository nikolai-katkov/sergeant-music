# ADR-001: MVVM for Phase 1

**Date:** 2026-01-17
**Status:** Accepted
**Deciders:** Architecture team, Product owner

## Context

SergeantMusic is a complex iOS app requiring:
- Real-time audio processing on dedicated thread
- MIDI integration with precise timing
- Multiple view modes with synchronized visualization
- User is new to iOS development

We need to choose an architecture pattern: MVVM (Model-View-ViewModel) or TCA (The Composable Architecture).

## Decision

Use **MVVM + Coordinators** for Phase 1 MVP, with clear migration path to TCA if needed in Phase 2+.

## Rationale

### Why MVVM?
1. **Learning Curve:** Standard iOS pattern with vast resources
2. **Development Velocity:** Faster initial development
3. **Audio Independence:** Audio threading is architecture-agnostic - both MVVM and TCA require the same lock-free patterns
4. **Flexibility:** No framework lock-in
5. **Debugging:** Standard Xcode tools work well
6. **Community:** Massive ecosystem and examples

### Why Not TCA (Yet)?
1. **Steep Learning Curve:** User is new to iOS - learning SwiftUI + AVAudioEngine + Core MIDI + TCA simultaneously is high risk
2. **Boilerplate Overhead:** TCA requires significant setup code
3. **Audio Complexity:** The hard part (audio threading) is the same in both architectures
4. **Framework Constraints:** TCA imposes patterns that may not fit audio use case

### Key Insight
**Audio threading concerns are orthogonal to UI architecture choice.** Neither MVVM nor TCA solves real-time audio challenges - both require:
- Lock-free ring buffer for audio → main thread communication
- Audio operations on dedicated queue
- 60 Hz polling on main thread
- Sample-accurate scheduling

The audio subsystem architecture is identical regardless of MVVM vs TCA.

## Consequences

### Positive
- ✅ Faster time to working MVP
- ✅ Lower barrier to entry for new iOS developer
- ✅ Can focus effort on audio engine (the hard part)
- ✅ Standard debugging tools
- ✅ Clear migration path exists

### Negative
- ❌ May encounter state management challenges at scale
- ❌ Requires discipline to keep ViewModels testable
- ❌ Less predictable state flow than TCA
- ❌ Potential refactoring if migrating to TCA

### Mitigation
- Use PracticeCoordinator pattern to centralize complex state coordination
- Keep ViewModels focused on UI transformation only
- Maintain unidirectional data flow (Audio → Coordinator → ViewModels → Views)
- Write comprehensive unit tests
- Reassess in Phase 2 if state bugs become frequent

## Alternatives Considered

### TCA (The Composable Architecture)
- **Pros:** Predictable state flow, excellent testability, built-in effect handling
- **Cons:** Steep learning curve, high boilerplate, slower initial velocity
- **Verdict:** Better for experienced iOS developers or apps with complex async workflows

### Custom Architecture
- **Pros:** Tailored to specific needs
- **Cons:** No community support, reinventing patterns
- **Verdict:** Not worth the effort

## References
- [MVVM vs TCA Comparison](../architecture/mvvm-vs-tca-comparison.md)
- [Architecture Overview](../architecture/architecture-overview.md)
- [State Management](../architecture/state-management.md)

## Review Trigger
Reassess architecture choice if:
- State synchronization bugs become frequent (> 1 per week)
- ViewModels exceed 300 lines regularly
- Testing becomes painful
- Cross-ViewModel coordination becomes complex

## Notes
This decision can be revisited after MVP validation. Migration path to TCA is well-documented and feasible if complexity warrants it.
