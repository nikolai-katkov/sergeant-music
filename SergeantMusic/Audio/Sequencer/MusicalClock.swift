//
//  MusicalClock.swift
//  SergeantMusic
//
//  Manages musical time and converts between beats/bars and sample time.
//  Thread-safe value type (no locks needed).
//

import Foundation
import AVFoundation

/// Musical clock for converting between musical time (beats/bars) and sample time
///
/// This is a thread-safe value type that performs time conversions.
/// All calculations are deterministic and lock-free.
class MusicalClock {
    // MARK: - Properties

    /// Current tempo in beats per minute (BPM)
    var tempo: Double {
        didSet {
            // Ensure tempo is within valid range
            tempo = max(40, min(240, tempo))
        }
    }

    /// Current time signature
    var timeSignature: TimeSignature

    /// Sample rate (typically 44100 Hz)
    let sampleRate: Double

    /// Current playback position in samples
    private(set) var currentSampleTime: Int64 = 0

    // MARK: - Initialization

    /// Create a musical clock
    /// - Parameters:
    ///   - tempo: Initial tempo in BPM (default: 120)
    ///   - timeSignature: Time signature (default: 4/4)
    ///   - sampleRate: Audio sample rate (default: 44100 Hz)
    init(tempo: Double = 120.0,
         timeSignature: TimeSignature = .fourFour,
         sampleRate: Double = 44100.0) {
        self.tempo = max(40, min(240, tempo))
        self.timeSignature = timeSignature
        self.sampleRate = sampleRate
    }

    // MARK: - Time Conversions

    /// Calculate samples per beat at current tempo
    var samplesPerBeat: Double {
        // 60 seconds per minute / BPM = seconds per beat
        // seconds per beat * sample rate = samples per beat
        return (60.0 / tempo) * sampleRate
    }

    /// Convert beat number to sample time
    /// - Parameter beat: Beat number (0.0 = start, 1.0 = first beat, etc.)
    /// - Returns: Sample time
    func beatToSampleTime(_ beat: Double) -> Int64 {
        return Int64(beat * samplesPerBeat)
    }

    /// Convert sample time to beat number
    /// - Parameter sampleTime: Sample time
    /// - Returns: Beat number (fractional)
    func sampleTimeToBeat(_ sampleTime: Int64) -> Double {
        return Double(sampleTime) / samplesPerBeat
    }

    /// Get bar number from sample time
    /// - Parameter sampleTime: Sample time
    /// - Returns: Bar number (0-indexed)
    func sampleTimeToBar(_ sampleTime: Int64) -> Int {
        let beat = sampleTimeToBeat(sampleTime)
        return Int(beat / Double(timeSignature.beatsPerBar))
    }

    /// Get beat within bar from sample time
    /// - Parameter sampleTime: Sample time
    /// - Returns: Beat within bar (1-indexed, 1 to beatsPerBar)
    func sampleTimeToBeatInBar(_ sampleTime: Int64) -> Int {
        let totalBeat = sampleTimeToBeat(sampleTime)
        let beatInBar = totalBeat.truncatingRemainder(dividingBy: Double(timeSignature.beatsPerBar))
        return Int(beatInBar) + 1  // 1-indexed for display
    }

    /// Convert bar and beat to sample time
    /// - Parameters:
    ///   - bar: Bar number (0-indexed)
    ///   - beat: Beat within bar (0-indexed)
    /// - Returns: Sample time
    func barBeatToSampleTime(bar: Int, beat: Int) -> Int64 {
        let totalBeat = Double(bar * timeSignature.beatsPerBar + beat)
        return beatToSampleTime(totalBeat)
    }

    // MARK: - Playback Position

    /// Advance the clock by a number of samples
    /// - Parameter samples: Number of samples to advance
    /// - Note: Call this from audio render callback to track position
    func advance(by samples: AVAudioFrameCount) {
        currentSampleTime += Int64(samples)
    }

    /// Set playback position
    /// - Parameter sampleTime: New playback position in samples
    func seek(to sampleTime: Int64) {
        currentSampleTime = max(0, sampleTime)
    }

    /// Reset playback to start
    func reset() {
        currentSampleTime = 0
    }

    // MARK: - Current Position Accessors

    /// Current beat number (fractional)
    var currentBeat: Double {
        return sampleTimeToBeat(currentSampleTime)
    }

    /// Current bar number (0-indexed)
    var currentBar: Int {
        return sampleTimeToBar(currentSampleTime)
    }

    /// Current beat within bar (1-indexed for display)
    var currentBeatInBar: Int {
        return sampleTimeToBeatInBar(currentSampleTime)
    }

    // MARK: - Quantization Helpers

    /// Round beat to nearest grid point
    /// - Parameters:
    ///   - beat: Beat number to quantize
    ///   - subdivision: Grid subdivision (1.0 = quarter note, 0.5 = eighth note, etc.)
    /// - Returns: Quantized beat number
    func quantizeBeat(_ beat: Double, to subdivision: Double) -> Double {
        return round(beat / subdivision) * subdivision
    }

    /// Get next beat boundary after given sample time
    /// - Parameter sampleTime: Current sample time
    /// - Returns: Sample time of next beat
    func nextBeatBoundary(after sampleTime: Int64) -> Int64 {
        let beat = sampleTimeToBeat(sampleTime)
        let nextBeat = ceil(beat)
        return beatToSampleTime(nextBeat)
    }

    /// Get next bar boundary after given sample time
    /// - Parameter sampleTime: Current sample time
    /// - Returns: Sample time of next bar
    func nextBarBoundary(after sampleTime: Int64) -> Int64 {
        let bar = sampleTimeToBar(sampleTime)
        let nextBar = bar + 1
        return barBeatToSampleTime(bar: nextBar, beat: 0)
    }
}

// MARK: - CustomStringConvertible

extension MusicalClock: CustomStringConvertible {
    var description: String {
        return "Clock(tempo: \(tempo) BPM, bar: \(currentBar + 1), beat: \(currentBeatInBar)/\(timeSignature.beatsPerBar))"
    }
}
