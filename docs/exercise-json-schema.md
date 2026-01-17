# Exercise JSON Schema Specification

**Version:** 1.0
**Date:** 2026-01-17
**Status:** Draft

## Overview

SergeantMusic exercises support two types:
1. **Pattern-Based:** Algorithmically generated from pattern definitions
2. **Explicit:** Manually specified notes and chords

This document specifies the JSON schema for both types.

## Schema Types

### Root Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "exerciseType", "title", "key", "tempo"],
  "properties": {
    "id": {"type": "string", "pattern": "^[a-z0-9-]+$"},
    "exerciseType": {"enum": ["pattern", "explicit", "hybrid"]},
    "title": {"type": "string", "minLength": 1, "maxLength": 100},
    "description": {"type": "string", "maxLength": 500},
    "key": {"type": "string", "pattern": "^[A-G][#b]?$"},
    "allowRandomKey": {"type": "boolean", "default": false},
    "tempo": {"type": "number", "minimum": 40, "maximum": 240},
    "timeSignature": {"type": "string", "pattern": "^\\d+/\\d+$", "default": "4/4"},
    "grooveStyle": {"type": "string"},
    "difficulty": {"enum": ["beginner", "intermediate", "advanced"]},
    "category": {"type": "string"},
    "tags": {"type": "array", "items": {"type": "string"}},
    "allowedViews": {
      "type": "array",
      "items": {"enum": ["fretboard", "notation", "tab", "timeline"]},
      "default": ["fretboard", "notation", "tab", "timeline"]
    },
    "estimatedDuration": {"type": "number", "description": "Duration in seconds"}
  }
}
```

## Pattern-Based Exercise

### Full Example

```json
{
  "id": "pattern-001-maj7-arpeggios-classic",
  "exerciseType": "pattern",
  "title": "Major 7th Chord Arpeggios - Classic Position",
  "description": "Practice all diatonic 7th chord arpeggios in a major scale using the classic fingering position (frets 1-4). Includes all inversions and rhythmic variations.",
  "key": "F",
  "allowRandomKey": true,
  "tempo": 80,
  "timeSignature": "4/4",
  "grooveStyle": "metronome-only",
  "difficulty": "intermediate",
  "category": "arpeggios",
  "tags": ["7th-chords", "classic-position", "inversions"],
  "allowedViews": ["fretboard", "tab"],

  "pattern": {
    "type": "arpeggio-sequence",
    "scale": "major",
    "chordTypes": ["maj7", "min7", "min7", "maj7", "dom7", "min7", "min7b5"],
    "rootDegrees": [1, 2, 3, 4, 5, 6, 7],

    "sequences": [
      {
        "name": "root-position-ascending",
        "intervals": [1, 3, 5, 7],
        "direction": "ascending",
        "octaveRange": 1
      },
      {
        "name": "first-inversion-ascending",
        "intervals": [3, 5, 7, 1],
        "direction": "ascending",
        "octaveRange": 1
      },
      {
        "name": "second-inversion-ascending",
        "intervals": [5, 7, 1, 3],
        "direction": "ascending",
        "octaveRange": 1
      },
      {
        "name": "third-inversion-ascending",
        "intervals": [7, 1, 3, 5],
        "direction": "ascending",
        "octaveRange": 1
      },
      {
        "name": "root-position-descending",
        "intervals": [1, 3, 5, 7],
        "direction": "descending",
        "octaveRange": 1
      },
      {
        "name": "first-inversion-descending",
        "intervals": [3, 5, 7, 1],
        "direction": "descending",
        "octaveRange": 1
      },
      {
        "name": "second-inversion-descending",
        "intervals": [5, 7, 1, 3],
        "direction": "descending",
        "octaveRange": 1
      }
    ],

    "rhythmicPatterns": [
      {
        "name": "upbeat",
        "noteDurations": [0.5, 0.5, 0.5, 0.5],
        "description": "Continuous eighth notes"
      },
      {
        "name": "upbeat-downbeat",
        "noteDurations": [0.5, 0.5, 1.0, 1.0],
        "description": "Two eighths, two quarters"
      }
    ]
  },

  "position": {
    "name": "classic",
    "startFret": 1,
    "endFret": 4,
    "fingerMap": {
      "1": [1, 2],
      "2": [3],
      "3": [4],
      "4": []
    },
    "startString": 6,
    "endString": 1,
    "stringRules": {
      "default": {
        "maxNotes": 3,
        "preferredNotes": 3
      },
      "exceptions": [
        {
          "string": 2,
          "maxNotes": 2,
          "condition": "adjacent_string_has_note_in_position",
          "adjacentString": 3
        }
      ]
    }
  },

  "metadata": {
    "author": "SergeantMusic",
    "createdDate": "2026-01-17",
    "version": "1.0",
    "license": "CC0"
  }
}
```

### Pattern Types

#### 1. Arpeggio Sequence
```json
{
  "type": "arpeggio-sequence",
  "scale": "major" | "minor" | "harmonic-minor" | "melodic-minor",
  "chordTypes": ["maj", "min", "dim", "aug", "maj7", "min7", "dom7", "min7b5"],
  "rootDegrees": [1, 2, 3, 4, 5, 6, 7],
  "sequences": [/* sequence definitions */]
}
```

#### 2. Scale Pattern
```json
{
  "type": "scale-pattern",
  "scale": "major",
  "pattern": "3-notes-per-string" | "pentatonic" | "modal",
  "direction": "ascending" | "descending" | "both",
  "octaves": 1 | 2,
  "sequences": [/* sequence definitions */]
}
```

#### 3. Interval Pattern
```json
{
  "type": "interval-pattern",
  "scale": "major",
  "interval": 3 | 4 | 5 | 6,
  "direction": "ascending" | "descending",
  "sequences": [/* sequence definitions */]
}
```

#### 4. Chord Progression Pattern
```json
{
  "type": "chord-progression",
  "progression": ["I", "IV", "V", "I"],
  "voicingType": "triads" | "7ths" | "extended",
  "strummingPattern": {
    "pattern": [1, 0, 1, 0, 1, 1],
    "duration": 0.25
  }
}
```

### Position Definition

```json
{
  "position": {
    "name": "classic" | "position-2" | "position-3" | "custom",
    "startFret": 1,
    "endFret": 4,
    "fingerMap": {
      "1": [1, 2],   // Finger 1 covers frets 1 and 2
      "2": [3],      // Finger 2 covers fret 3
      "3": [4],      // Finger 3 covers fret 4
      "4": []        // Finger 4 (stretch) if needed
    },
    "startString": 6,
    "endString": 1,
    "stringRules": {
      "default": {
        "maxNotes": 3,
        "preferredNotes": 3
      },
      "exceptions": [
        {
          "string": 2,
          "maxNotes": 2,
          "condition": "adjacent_string_has_note_in_position",
          "adjacentString": 3,
          "reason": "Avoid awkward stretches on B string"
        }
      ]
    },
    "crossStringRules": {
      "allowOpenStrings": false,
      "maxStretch": 4,
      "preferredFingeringStyle": "one-finger-per-fret"
    }
  }
}
```

## Explicit Exercise

### Full Example

```json
{
  "id": "song-001-simple-melody-c",
  "exerciseType": "explicit",
  "title": "Simple Melody in C Major",
  "description": "A beginner-friendly melody using C major scale notes.",
  "key": "C",
  "tempo": 120,
  "timeSignature": "4/4",
  "grooveStyle": "pop-ballad",
  "difficulty": "beginner",
  "category": "melodies",
  "tags": ["melody", "c-major", "beginner"],
  "allowedViews": ["fretboard", "notation", "tab", "timeline"],

  "chords": [
    {
      "symbol": "C",
      "voicing": [0, 2, 2, 0, 1, 0],
      "root": "C",
      "type": "major",
      "startBeat": 0,
      "duration": 4
    },
    {
      "symbol": "G",
      "voicing": [3, 2, 0, 0, 0, 3],
      "root": "G",
      "type": "major",
      "startBeat": 4,
      "duration": 4
    },
    {
      "symbol": "Am",
      "voicing": [0, 0, 2, 2, 1, 0],
      "root": "A",
      "type": "minor",
      "startBeat": 8,
      "duration": 4
    },
    {
      "symbol": "F",
      "voicing": [1, 3, 3, 2, 1, 1],
      "root": "F",
      "type": "major",
      "startBeat": 12,
      "duration": 4
    }
  ],

  "melody": [
    {
      "pitch": "E4",
      "scaleDegree": 3,
      "startBeat": 0,
      "duration": 1,
      "string": 2,
      "fret": 5,
      "finger": 3,
      "dynamic": "mf"
    },
    {
      "pitch": "G4",
      "scaleDegree": 5,
      "startBeat": 1,
      "duration": 1,
      "string": 1,
      "fret": 3,
      "finger": 1,
      "dynamic": "mf"
    },
    {
      "pitch": "C5",
      "scaleDegree": 1,
      "startBeat": 2,
      "duration": 2,
      "string": 1,
      "fret": 8,
      "finger": 4,
      "dynamic": "f"
    }
  ],

  "bassLine": [
    {
      "pitch": "C2",
      "startBeat": 0,
      "duration": 0.5,
      "dynamic": "mf"
    },
    {
      "pitch": "E2",
      "startBeat": 0.5,
      "duration": 0.5,
      "dynamic": "mf"
    }
  ],

  "metadata": {
    "author": "SergeantMusic",
    "createdDate": "2026-01-17",
    "source": "original",
    "copyright": "Public Domain"
  }
}
```

## Hybrid Exercise

Combines explicit chords with generated patterns:

```json
{
  "id": "hybrid-001-blues-improv",
  "exerciseType": "hybrid",
  "title": "Blues Improvisation in E",
  "key": "E",
  "tempo": 100,

  "chords": [
    /* Explicit 12-bar blues progression */
  ],

  "pattern": {
    "type": "scale-pattern",
    "scale": "minor-pentatonic",
    /* Pattern for improvisation */
  },

  "position": {
    /* Position constraints */
  }
}
```

## Field Descriptions

### NoteEvent (Explicit)
- `pitch`: Absolute pitch (e.g., "C4", "F#5")
- `scaleDegree`: Scale degree (1-7)
- `startBeat`: When note starts (beats from exercise start)
- `duration`: Note length in beats
- `string`: Guitar string (1-6, where 1 = high E)
- `fret`: Fret number (0-24)
- `finger`: Suggested finger (0=open, 1-4=fingers)
- `dynamic`: Volume marking (pp, p, mp, mf, f, ff)

### ChordEvent
- `symbol`: Chord symbol (e.g., "Cmaj7", "Dm", "G7")
- `voicing`: Array of 6 fret numbers (low E to high E), -1 for muted
- `root`: Root note (A-G with optional # or b)
- `type`: Chord type (major, minor, dim, aug, maj7, min7, dom7, etc.)
- `startBeat`: When chord starts
- `duration`: Chord duration in beats

## Validation Rules

### All Exercises
1. `tempo` must be 40-240 BPM
2. `key` must be valid note name (A-G with optional #/b)
3. `timeSignature` must be valid (e.g., "4/4", "3/4", "6/8")
4. `id` must be unique, lowercase, hyphenated

### Pattern Exercises
1. `pattern.type` must be valid pattern type
2. `position` must be defined if pattern uses fretboard
3. `rootDegrees` length must match `chordTypes` length
4. `sequences` must have at least one sequence

### Explicit Exercises
1. `melody` or `chords` must be present (or both)
2. All `startBeat` values must be >= 0
3. All `duration` values must be > 0
4. String numbers must be 1-6
5. Fret numbers must be 0-24
6. Finger numbers must be 0-4

## Example Pattern Library

### Pattern 1: Major Scale (3 Notes Per String)
```json
{
  "id": "pattern-scale-major-3nps-pos1",
  "exerciseType": "pattern",
  "title": "Major Scale - 3 Notes Per String - Position 1",
  "pattern": {
    "type": "scale-pattern",
    "scale": "major",
    "pattern": "3-notes-per-string",
    "direction": "ascending"
  }
}
```

### Pattern 2: Triad Arpeggios
```json
{
  "id": "pattern-arp-triads-major-scale",
  "exerciseType": "pattern",
  "title": "Triad Arpeggios - Major Scale",
  "pattern": {
    "type": "arpeggio-sequence",
    "scale": "major",
    "chordTypes": ["maj", "min", "min", "maj", "maj", "min", "dim"],
    "rootDegrees": [1, 2, 3, 4, 5, 6, 7],
    "sequences": [
      {"intervals": [1, 3, 5], "direction": "ascending"}
    ]
  }
}
```

### Pattern 3: Diatonic Thirds
```json
{
  "id": "pattern-intervals-3rds-major",
  "exerciseType": "pattern",
  "title": "Diatonic Thirds - Major Scale",
  "pattern": {
    "type": "interval-pattern",
    "scale": "major",
    "interval": 3,
    "direction": "ascending"
  }
}
```

## File Organization

```
Resources/Exercises/
  patterns/
    scales/
      pattern-scale-major-3nps-pos1.json
      pattern-scale-minor-3nps-pos1.json
    arpeggios/
      pattern-arp-7ths-major-scale.json
      pattern-arp-triads-minor-scale.json
    intervals/
      pattern-intervals-3rds-major.json
      pattern-intervals-4ths-major.json
  explicit/
    songs/
      song-001-simple-melody-c.json
    chord-progressions/
      prog-001-i-iv-v-c.json
  hybrid/
    hybrid-001-blues-improv.json
```

## Notes

- All beat values are in quarter notes (4/4 time)
- String numbering: 1=high E, 6=low E (standard guitar)
- Fret 0 = open string
- Finger 0 = open, 1-4 = index through pinky
- Pattern exercises generate notes at runtime
- Explicit exercises store all notes in JSON

## Version History

- **1.0** (2026-01-17): Initial schema with pattern and explicit support
