# ADR-009: Manual JSON Exercise Authoring

**Date:** 2026-01-17
**Status:** Accepted

## Context

Exercise creation options for Phase 1:
1. Manual JSON editing
2. Visual editor
3. Import from MIDI/MusicXML
4. Programmatic generation

## Decision

Phase 1: **Manual JSON authoring**
Phase 2: **Visual exercise editor**

## Rationale

### Why Manual for Phase 1?
- **Focus on Core:** MVP focus is playback engine + visualization
- **Fast to Market:** Don't need to build editor first
- **Validate Format:** Learn what schema works before building tools
- **Small Scale:** Only need 10-15 exercises for MVP
- **Iteration:** Easy to refine JSON format

### Why Not Editor in Phase 1?
- **Complexity:** Editor is a major feature itself
- **Unknown Requirements:** Don't know ideal UX yet
- **Development Time:** Would delay MVP by weeks
- **Premature:** Format may change during development

## Implementation

### Phase 1 Workflow
1. Create JSON file from template
2. Edit in text editor (VS Code with JSON schema)
3. Validate on app launch
4. Fix errors, iterate

### JSON Schema Validation
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "title", "key", "tempo", "chords"],
  "properties": {
    "tempo": {
      "type": "number",
      "minimum": 40,
      "maximum": 240
    }
  }
}
```

### Example Templates
Provide templates for common patterns:
- Simple chord progression (4 chords, 4 bars)
- 12-bar blues
- Jazz ii-V-I
- Pop progression (I-V-vi-IV)

## Consequences

### Positive
- ✅ Fast MVP development
- ✅ Learn ideal JSON format
- ✅ Can refine schema easily
- ✅ Focus on core playback features

### Negative
- ❌ Manual work to create exercises
- ❌ Error-prone (typos, invalid JSON)
- ❌ Not scalable long-term
- ❌ High barrier for user-created content

### Mitigation
- Create comprehensive templates
- Add JSON schema for IDE validation
- Implement strict validation on load
- Clear error messages
- Build editor in Phase 2

## Phase 2: Visual Editor

### Features
- Drag-and-drop chord placement
- Piano roll for melody editing
- Groove pattern selection
- Real-time preview
- Export to JSON
- Import from JSON

### Timeline
- Week 5-6 of development
- After MVP validated

## Effort Estimate

### Phase 1 (Manual)
- JSON schema: 2 hours
- Templates: 2 hours
- Create 10-15 exercises: 10 hours
- **Total: ~14 hours**

### Phase 2 (Editor)
- UI design: 8 hours
- Implementation: 40 hours
- Testing: 8 hours
- **Total: ~56 hours**

## References
- [ADR-004: JSON Exercise Storage](ADR-004-json-exercise-storage.md)
- [Roadmap](../roadmap.md)

## Review Trigger
Move to visual editor when:
- MVP validated
- JSON format stable
- User demand for custom exercises

## Notes
Manual authoring is acceptable for MVP with limited exercise count. Editor is high priority for Phase 2.
