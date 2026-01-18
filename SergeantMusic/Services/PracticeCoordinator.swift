//
//  PracticeCoordinator.swift
//  SergeantMusic
//
//  Central coordinator bridging audio engine, metronome, and UI.
//  Week 1 simplified version using Timer for UI updates.
//

import Foundation
import Combine
import AVFoundation

/// Practice session coordinator
///
/// Responsibilities (Week 1 scope):
/// - Initialize and manage audio components
/// - Schedule metronome clicks
/// - Update UI with playback position
/// - Handle play/pause/tempo changes
@MainActor
class PracticeCoordinator: ObservableObject {
    // MARK: - Published Properties

    /// Is playback active?
    @Published var isPlaying: Bool = false

    // MARK: - Properties

    /// Audio session manager
    private let sessionManager: AudioSessionManager

    /// Audio engine manager
    private let engineManager: AudioEngineManager

    /// Musical clock for time conversions
    private let musicalClock: MusicalClock

    /// Metronome node
    private let metronome: MetronomeNode

    /// Timer for updating UI (60 Hz)
    private var updateTimer: Timer?

    /// Playback position publisher
    let playbackPositionPublisher = PassthroughSubject<PlaybackPosition, Never>()

    /// Queue for audio operations
    private let audioQueue = DispatchQueue(label: "com.sergeantmusic.audio",
                                          qos: .userInteractive)

    /// Lookahead beats for scheduling
    private let lookaheadBeats: Double = 4.0

    /// Last scheduled beat
    private var lastScheduledBeat: Double = 0.0

    // MARK: - Initialization

    /// Create practice coordinator
    /// - Throws: If audio engine initialization fails
    init() throws {
        self.sessionManager = AudioSessionManager()
        self.engineManager = try AudioEngineManager()
        self.musicalClock = MusicalClock(tempo: 120.0, timeSignature: .fourFour)
        self.metronome = try MetronomeNode(audioFormat: engineManager.audioFormat)

        setupAudioEngine()
        setupInterruptionHandling()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        do {
            // Configure audio session
            try sessionManager.configureForPractice()

            // Attach metronome to engine
            try engineManager.attachMetronome(metronome)

            // Initialize engine
            try engineManager.initialize()

        } catch {
            print("Failed to setup audio engine: \(error)")
        }
    }

    private func setupInterruptionHandling() {
        sessionManager.onInterruptionBegan = { [weak self] in
            self?.stop()
        }

        sessionManager.onInterruptionEnded = { [weak self] in
            // Don't auto-resume, let user decide
        }
    }

    // MARK: - Playback Control

    /// Start playback
    func start() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Start audio engine
                try self.engineManager.start()

                // Start metronome player
                self.metronome.start()

                // Reset scheduling
                self.lastScheduledBeat = 0.0
                self.musicalClock.reset()

                // Schedule initial clicks
                self.scheduleMetronomeClicks()

                // Update UI state
                Task { @MainActor in
                    self.isPlaying = true
                    self.startUpdateTimer()
                }

            } catch {
                print("Failed to start playback: \(error)")
            }
        }
    }

    /// Stop playback
    func stop() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop metronome
            self.metronome.stop()

            // Stop audio engine
            self.engineManager.stop()

            // Update UI state
            Task { @MainActor in
                self.isPlaying = false
                self.stopUpdateTimer()
            }
        }
    }

    /// Reset playback to beginning
    func reset() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            let wasPlaying = self.isPlaying

            if wasPlaying {
                self.stop()
            }

            self.musicalClock.reset()
            self.lastScheduledBeat = 0.0

            Task { @MainActor in
                self.publishPosition()
            }

            if wasPlaying {
                self.start()
            }
        }
    }

    /// Set tempo
    /// - Parameter bpm: Tempo in beats per minute
    func setTempo(_ bpm: Double) {
        audioQueue.async { [weak self] in
            self?.musicalClock.tempo = bpm
        }
    }

    // MARK: - Metronome Scheduling

    private func scheduleMetronomeClicks() {
        guard let currentTime = engineManager.currentTime() else { return }

        let currentSampleTime = currentTime.sampleTime
        let currentBeat = musicalClock.sampleTimeToBeat(currentSampleTime)

        // Calculate next beat to schedule
        let nextBeat = max(ceil(currentBeat), lastScheduledBeat)

        // Schedule lookahead beats
        for i in 0..<Int(lookaheadBeats) {
            let beat = nextBeat + Double(i)
            let sampleTime = musicalClock.beatToSampleTime(beat)

            let audioTime = AVAudioTime(
                sampleTime: sampleTime,
                atRate: musicalClock.sampleRate
            )

            // Check if this is an accent (downbeat)
            let isAccent = Int(beat) % musicalClock.timeSignature.beatsPerBar == 0

            metronome.scheduleClick(at: audioTime, isAccent: isAccent)
        }

        lastScheduledBeat = nextBeat + lookaheadBeats
    }

    // MARK: - UI Updates

    private func startUpdateTimer() {
        stopUpdateTimer()

        // 60 Hz timer for smooth UI updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePlaybackPosition()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updatePlaybackPosition() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // Get current audio time
            guard let currentTime = self.engineManager.currentTime() else { return }

            let sampleTime = currentTime.sampleTime

            // Update musical clock
            self.musicalClock.seek(to: sampleTime)

            // Schedule more clicks if needed
            let currentBeat = self.musicalClock.currentBeat
            if currentBeat >= self.lastScheduledBeat - self.lookaheadBeats / 2 {
                self.scheduleMetronomeClicks()
            }

            // Publish position to UI
            Task { @MainActor in
                self.publishPosition()
            }
        }
    }

    private func publishPosition() {
        let position = PlaybackPosition(
            beat: musicalClock.currentBeat,
            bar: musicalClock.currentBar,
            beatInBar: musicalClock.currentBeatInBar
        )
        playbackPositionPublisher.send(position)
    }
}
