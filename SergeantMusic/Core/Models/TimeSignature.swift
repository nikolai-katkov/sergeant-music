//
//  TimeSignature.swift
//  SergeantMusic
//
//  Core model representing musical time signatures.
//

import Foundation

/// Represents a musical time signature (e.g., 4/4, 3/4, 6/8)
struct TimeSignature: Equatable, Codable {
    /// Number of beats per bar (numerator)
    let beatsPerBar: Int

    /// Note value that represents one beat (denominator)
    /// 4 = quarter note, 8 = eighth note, etc.
    let noteValue: Int

    /// Create a time signature
    /// - Parameters:
    ///   - beatsPerBar: Number of beats per bar (e.g., 4 for 4/4)
    ///   - noteValue: Note value for one beat (e.g., 4 for quarter note)
    init(beatsPerBar: Int, noteValue: Int) {
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
    }

    // MARK: - Common Presets

    /// 4/4 time signature (common time)
    static let fourFour = TimeSignature(beatsPerBar: 4, noteValue: 4)

    /// 3/4 time signature (waltz time)
    static let threeFour = TimeSignature(beatsPerBar: 3, noteValue: 4)

    /// 6/8 time signature
    static let sixEight = TimeSignature(beatsPerBar: 6, noteValue: 8)

    /// 5/4 time signature
    static let fiveFour = TimeSignature(beatsPerBar: 5, noteValue: 4)

    /// 7/8 time signature
    static let sevenEight = TimeSignature(beatsPerBar: 7, noteValue: 8)

    // MARK: - Helpers

    /// String representation (e.g., "4/4")
    var description: String {
        return "\(beatsPerBar)/\(noteValue)"
    }
}
