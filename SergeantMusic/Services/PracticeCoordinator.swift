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

    /// Track when playback actually started
    private var playbackStartTime: Date?

    /// Track when scheduling started (host time)
    private var schedulingStartHostTime: UInt64 = 0

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
            try sessionManager.configureForPractice()
            try engineManager.attachMetronome(metronome)
            try engineManager.initialize()
        } catch {
            print("❌ Failed to setup audio engine: \(error)")
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
                // Stop engine first if it's running
                if self.engineManager.isRunning {
                    self.engineManager.stop()
                }

                try self.engineManager.start()
                self.metronome.start()

                // Reset scheduling - start from beat 0
                self.lastScheduledBeat = 0.0
                self.musicalClock.reset()
                self.playbackStartTime = Date()
                self.schedulingStartHostTime = mach_absolute_time()

                // Give the engine a moment to stabilize before scheduling
                // This ensures lastRenderTime is valid
                usleep(10000)  // 10ms delay

                self.scheduleMetronomeClicks()

                // Update UI state
                Task { @MainActor in
                    self.isPlaying = true
                    self.startUpdateTimer()
                }

            } catch {
                print("❌ Failed to start playback: \(error)")
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
            guard let self = self else { return }

            self.musicalClock.tempo = bpm

            // If playing, we need to reschedule with new tempo
            if self.isPlaying {
                // Stop the player node to clear scheduled buffers
                self.metronome.stop()

                // Reset scheduling to current beat
                guard let startTime = self.playbackStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let oldSecondsPerBeat = 60.0 / self.musicalClock.tempo
                let currentBeat = elapsed / oldSecondsPerBeat

                // Reset timing anchors
                self.lastScheduledBeat = floor(currentBeat)
                self.playbackStartTime = Date()
                self.schedulingStartHostTime = mach_absolute_time()

                // Restart player and reschedule
                self.metronome.start()
                self.scheduleMetronomeClicks()
            }
        }
    }

    // MARK: - Metronome Scheduling

    private func scheduleMetronomeClicks() {
        let currentBeat = self.lastScheduledBeat
        let secondsPerBeat = 60.0 / musicalClock.tempo

        // Get time base for conversion
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let toNanos = Double(timebase.numer) / Double(timebase.denom)

        for i in 0..<Int(lookaheadBeats) {
            let beat = currentBeat + Double(i)

            // Calculate absolute time since playback started
            // Beat 0 should play at +0.1s, Beat 1 at +0.6s, Beat 2 at +1.1s, etc.
            let absoluteOffsetSeconds = 0.1 + (beat * secondsPerBeat)

            // Convert to host time from the start
            let offsetNanos = absoluteOffsetSeconds * 1_000_000_000.0
            let offsetTicks = UInt64(offsetNanos / toNanos)
            let scheduledHostTime = schedulingStartHostTime + offsetTicks

            let audioTime = AVAudioTime(hostTime: scheduledHostTime)
            let isAccent = Int(beat) % musicalClock.timeSignature.beatsPerBar == 0

            metronome.scheduleClick(at: audioTime, isAccent: isAccent)
        }

        lastScheduledBeat = currentBeat + lookaheadBeats

        // Schedule next batch
        scheduleNextBatch()
    }

    private func scheduleNextBatch() {
        // Schedule next batch to trigger when we're halfway through current batch
        if lastScheduledBeat < 100 {  // Limit to 100 beats for Week 1 demo
            let samplesPerBeat = musicalClock.samplesPerBeat
            let sampleRate = musicalClock.sampleRate
            let scheduleNextDelay = (2.0 * samplesPerBeat) / sampleRate  // Re-schedule after 2 beats

            audioQueue.asyncAfter(deadline: .now() + scheduleNextDelay) { [weak self] in
                self?.scheduleMetronomeClicks()
            }
        }
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
        // Calculate current beat based on elapsed time
        guard let startTime = playbackStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let secondsPerBeat = 60.0 / musicalClock.tempo
        let elapsedBeats = elapsed / secondsPerBeat
        let currentBeat = elapsedBeats  // Start from beat 0

        // Calculate bar and beat within bar
        let bar = Int(currentBeat) / musicalClock.timeSignature.beatsPerBar
        let beatInBar = (Int(currentBeat) % musicalClock.timeSignature.beatsPerBar) + 1

        Task { @MainActor in
            let position = PlaybackPosition(
                beat: currentBeat,
                bar: bar,
                beatInBar: beatInBar
            )
            self.playbackPositionPublisher.send(position)
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
