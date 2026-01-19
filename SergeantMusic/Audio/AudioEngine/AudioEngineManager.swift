//
//  AudioEngineManager.swift
//  SergeantMusic
//
//  Manages AVAudioEngine lifecycle and audio node graph.
//

import Foundation
import AVFoundation

/// Manages the AVAudioEngine and audio node graph
///
/// Responsibilities:
/// - Initialize and configure AVAudioEngine
/// - Build audio node graph
/// - Connect nodes (metronome → mixer → output)
/// - Start/stop engine
/// - Monitor performance
class AudioEngineManager {
    // MARK: - Properties

    /// The audio engine
    let engine: AVAudioEngine

    /// Main mixer node
    let mainMixerNode: AVAudioMixerNode

    /// Audio format for all nodes
    let audioFormat: AVAudioFormat

    /// Is the engine currently running?
    private(set) var isRunning: Bool = false

    /// Output node (convenience accessor)
    var outputNode: AVAudioOutputNode {
        return engine.outputNode
    }

    // MARK: - Initialization

    /// Create audio engine manager
    /// - Throws: If audio format creation fails
    init() throws {
        self.engine = AVAudioEngine()
        self.mainMixerNode = engine.mainMixerNode

        // Get the actual output format from the system
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let actualSampleRate = outputFormat.sampleRate

        // Use the system's actual sample rate instead of forcing 44.1kHz
        // This ensures proper timing and avoids resampling
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: actualSampleRate,
            channels: outputFormat.channelCount,
            interleaved: false
        ) else {
            throw AudioEngineError.bufferAllocationFailed
        }

        self.audioFormat = format
    }

    // MARK: - Lifecycle

    /// Initialize the audio engine
    /// - Throws: Audio engine errors
    func initialize() throws {
        // Set mixer volume to maximum
        mainMixerNode.outputVolume = 1.0

        // NOTE: mainMixerNode is already connected to outputNode by AVAudioEngine
        // Do NOT manually connect it again as that can cause issues

        // Prepare the engine
        engine.prepare()
    }

    /// Start the audio engine
    /// - Throws: Audio engine start errors
    func start() throws {
        guard !isRunning else { return }

        try engine.start()
        isRunning = true
    }

    /// Stop the audio engine
    func stop() {
        guard isRunning else { return }

        engine.stop()
        isRunning = false
    }

    // MARK: - Node Management

    /// Attach metronome node to the engine
    /// - Parameter metronome: The metronome node to attach
    /// - Throws: If node attachment or connection fails
    func attachMetronome(_ metronome: MetronomeNode) throws {
        let playerNode = metronome.playerNode

        // Attach the player node if not already attached
        if !engine.attachedNodes.contains(playerNode) {
            engine.attach(playerNode)
        }

        // Connect: metronome player → main mixer
        engine.connect(
            playerNode,
            to: mainMixerNode,
            format: audioFormat
        )
    }

    /// Detach metronome node from engine
    /// - Parameter metronome: The metronome node to detach
    func detachMetronome(_ metronome: MetronomeNode) {
        let playerNode = metronome.playerNode

        if engine.attachedNodes.contains(playerNode) {
            engine.detach(playerNode)
        }
    }

    // MARK: - Timing

    /// Get current audio engine time
    /// - Returns: Current AVAudioTime, or nil if engine not running
    func currentTime() -> AVAudioTime? {
        guard isRunning else { return nil }

        // Get the time of the last render
        return engine.outputNode.lastRenderTime
    }

    /// Get current sample time
    /// - Returns: Current sample time, or 0 if engine not running
    func currentSampleTime() -> Int64 {
        guard let renderTime = currentTime(),
              let sampleTime = renderTime.sampleTime as Int64? else {
            return 0
        }
        return sampleTime
    }

    // MARK: - Performance Monitoring

    /// Check if engine is overloaded (buffer underruns)
    var isOverloaded: Bool {
        // Note: AVAudioEngine doesn't expose overload state directly
        // In production, you'd monitor CPU usage or use other metrics
        return false
    }

    /// Get CPU load (approximate)
    /// Note: This is a simplified version. For production,
    /// use more sophisticated monitoring
    var cpuLoad: Float {
        // Placeholder - would need system-level monitoring
        return 0.0
    }
}
