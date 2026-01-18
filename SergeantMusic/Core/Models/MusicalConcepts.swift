//
//  MusicalConcepts.swift
//  SergeantMusic
//
//  Core musical domain models (Note, Pitch, etc.)
//

import Foundation

/// Musical pitch names
enum PitchClass: String, CaseIterable, Codable {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "D#"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "G#"
    case a = "A"
    case aSharp = "A#"
    case b = "B"

    /// Semitone offset from C (0-11)
    var semitoneOffset: Int {
        switch self {
        case .c: return 0
        case .cSharp: return 1
        case .d: return 2
        case .dSharp: return 3
        case .e: return 4
        case .f: return 5
        case .fSharp: return 6
        case .g: return 7
        case .gSharp: return 8
        case .a: return 9
        case .aSharp: return 10
        case .b: return 11
        }
    }

    /// Create pitch class from semitone offset (0-11)
    static func from(semitoneOffset: Int) -> PitchClass {
        let normalized = ((semitoneOffset % 12) + 12) % 12
        return allCases[normalized]
    }
}

/// Represents a musical note with pitch and octave
struct Note: Equatable, Codable, Hashable {
    /// Pitch class (C, D, E, etc.)
    let pitchClass: PitchClass

    /// Octave number (MIDI standard: C4 = middle C)
    let octave: Int

    /// Create a note
    /// - Parameters:
    ///   - pitchClass: The pitch class
    ///   - octave: The octave number (4 = middle C octave)
    init(_ pitchClass: PitchClass, octave: Int) {
        self.pitchClass = pitchClass
        self.octave = octave
    }

    // MARK: - MIDI Conversion

    /// MIDI note number (0-127, where C4 = 60)
    var midiNumber: Int {
        return (octave + 1) * 12 + pitchClass.semitoneOffset
    }

    /// Create note from MIDI number
    /// - Parameter midiNumber: MIDI note number (0-127)
    /// - Returns: Note corresponding to the MIDI number
    static func from(midiNumber: Int) -> Note {
        let octave = (midiNumber / 12) - 1
        let semitone = midiNumber % 12
        let pitchClass = PitchClass.from(semitoneOffset: semitone)
        return Note(pitchClass, octave: octave)
    }

    // MARK: - Transposition

    /// Transpose the note by a number of semitones
    /// - Parameter semitones: Number of semitones to transpose (positive = up, negative = down)
    /// - Returns: Transposed note
    func transposed(by semitones: Int) -> Note {
        let newMidi = midiNumber + semitones
        return Note.from(midiNumber: newMidi)
    }

    // MARK: - Common Notes

    static let c4 = Note(.c, octave: 4)  // Middle C
    static let a4 = Note(.a, octave: 4)  // A440 (concert pitch)

    // MARK: - Description

    var description: String {
        return "\(pitchClass.rawValue)\(octave)"
    }
}

// MARK: - Interval

/// Musical interval (distance between two notes in semitones)
struct Interval: Equatable, Codable {
    /// Number of semitones
    let semitones: Int

    init(_ semitones: Int) {
        self.semitones = semitones
    }

    // Common intervals
    static let unison = Interval(0)
    static let minorSecond = Interval(1)
    static let majorSecond = Interval(2)
    static let minorThird = Interval(3)
    static let majorThird = Interval(4)
    static let perfectFourth = Interval(5)
    static let tritone = Interval(6)
    static let perfectFifth = Interval(7)
    static let minorSixth = Interval(8)
    static let majorSixth = Interval(9)
    static let minorSeventh = Interval(10)
    static let majorSeventh = Interval(11)
    static let octave = Interval(12)
}

// MARK: - Stub Models for Future Expansion (Week 2+)

/// Placeholder for Chord model (to be implemented in Week 2)
struct Chord: Equatable, Codable {
    let rootNote: Note
    let notes: [Note]

    init(rootNote: Note, notes: [Note]) {
        self.rootNote = rootNote
        self.notes = notes
    }
}

/// Placeholder for Scale model (to be implemented in Week 4)
struct Scale: Equatable, Codable {
    let rootNote: Note
    let intervals: [Interval]

    init(rootNote: Note, intervals: [Interval]) {
        self.rootNote = rootNote
        self.intervals = intervals
    }
}
