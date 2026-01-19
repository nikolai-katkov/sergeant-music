//
//  MetronomeNode.swift
//  SergeantMusic
//
//  Metronome click generator using AVAudioPlayerNode.
//  Pre-generates click sounds and schedules them at precise times.
//

import Foundation
import AVFoundation

/// Metronome that generates click sounds
///
/// Uses AVAudioPlayerNode to schedule precise clicks.
/// Pre-generates two buffers: accent (downbeat) and regular beat.
class MetronomeNode {
    // MARK: - Properties

    /// The audio player node for playback
    let playerNode: AVAudioPlayerNode

    /// Audio format for click buffers
    private let audioFormat: AVAudioFormat

    /// Pre-generated buffer for accent (downbeat) click
    private let accentBuffer: AVAudioPCMBuffer

    /// Pre-generated buffer for regular beat click
    private let regularBuffer: AVAudioPCMBuffer

    // MARK: - Initialization

    /// Create a metronome node
    /// - Parameter audioFormat: Audio format (typically 44.1kHz, stereo)
    /// - Throws: If buffer generation fails
    init(audioFormat: AVAudioFormat) throws {
        self.audioFormat = audioFormat
        self.playerNode = AVAudioPlayerNode()

        // Generate click buffers
        self.accentBuffer = try MetronomeNode.generateClickBuffer(
            audioFormat: audioFormat,
            frequency: 1200.0,  // Higher pitch for accent
            duration: 0.05      // 50ms click
        )

        self.regularBuffer = try MetronomeNode.generateClickBuffer(
            audioFormat: audioFormat,
            frequency: 800.0,   // Lower pitch for regular beat
            duration: 0.05      // 50ms click
        )
    }

    // MARK: - Playback Control

    /// Start the player node
    func start() {
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    /// Stop the player node
    func stop() {
        playerNode.stop()
    }

    // MARK: - Click Scheduling

    /// Schedule a click at a specific time
    /// - Parameters:
    ///   - time: AVAudioTime when click should play (nil means ASAP)
    ///   - isAccent: Whether this is an accented click (downbeat)
    func scheduleClick(at time: AVAudioTime?, isAccent: Bool) {
        let buffer = isAccent ? accentBuffer : regularBuffer
        playerNode.scheduleBuffer(buffer, at: time, options: [])
    }

    /// Schedule multiple clicks
    /// - Parameter clicks: Array of (time, isAccent) tuples
    func scheduleClicks(_ clicks: [(time: AVAudioTime, isAccent: Bool)]) {
        for click in clicks {
            scheduleClick(at: click.time, isAccent: click.isAccent)
        }
    }

    // MARK: - Buffer Generation

    /// Generate a click sound buffer
    /// - Parameters:
    ///   - audioFormat: Audio format for the buffer
    ///   - frequency: Frequency of the click tone in Hz
    ///   - duration: Duration of the click in seconds
    /// - Returns: Audio buffer containing the click sound
    /// - Throws: If buffer allocation fails
    private static func generateClickBuffer(
        audioFormat: AVAudioFormat,
        frequency: Double,
        duration: TimeInterval
    ) throws -> AVAudioPCMBuffer {
        let sampleRate = audioFormat.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferAllocationFailed
        }

        buffer.frameLength = frameCount

        guard let floatChannelData = buffer.floatChannelData else {
            throw AudioEngineError.bufferAllocationFailed
        }

        let channelCount = Int(audioFormat.channelCount)
        let amplitude: Float = 0.5  // 50% volume

        // Generate sine wave with envelope
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let sineValue = sin(2.0 * .pi * frequency * time)

            // Apply exponential decay envelope for click effect
            let envelope = exp(-10.0 * time)  // Fast decay
            let sample = Float(sineValue * envelope) * amplitude

            // Write to all channels
            for channel in 0..<channelCount {
                floatChannelData[channel][frame] = sample
            }
        }

        return buffer
    }
}

// MARK: - Audio Engine Error

enum AudioEngineError: Error {
    case bufferAllocationFailed
    case engineNotRunning
    case nodeNotAttached
}
