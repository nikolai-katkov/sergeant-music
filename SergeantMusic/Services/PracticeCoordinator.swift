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

    /// Track starting beat position
    private var playbackStartBeat: Double = 0.0

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
            print("🎵 Configuring audio session...")
            try sessionManager.configureForPractice()
            print("✅ Audio session configured")

            print("🎵 Attaching metronome to engine...")
            try engineManager.attachMetronome(metronome)
            print("✅ Metronome attached")

            print("🎵 Initializing audio engine...")
            try engineManager.initialize()
            print("✅ Audio engine initialized")

        } catch {
            print("❌ Failed to setup audio engine: \(error)")
            print("   Error details: \(error.localizedDescription)")
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
        print("▶️ Start playback requested")
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Stop engine first if it's running
                if self.engineManager.isRunning {
                    self.engineManager.stop()
                }

                print("🎵 Starting audio engine...")
                try self.engineManager.start()
                print("✅ Audio engine started")

                print("🎵 Starting metronome player...")
                self.metronome.start()
                print("✅ Metronome player started")

                // Reset scheduling - start from beat 0
                self.lastScheduledBeat = 0.0
                self.musicalClock.reset()
                self.playbackStartTime = Date()
                self.playbackStartBeat = 0.0

                print("🎵 Scheduling initial metronome clicks...")
                self.scheduleMetronomeClicks()
                print("✅ Initial clicks scheduled")

                // Update UI state
                Task { @MainActor in
                    self.isPlaying = true
                    self.startUpdateTimer()
                    print("✅ Playback started successfully")
                }

            } catch {
                print("❌ Failed to start playback: \(error)")
                print("   Error details: \(error.localizedDescription)")
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
        print("🎼 Setting tempo to \(Int(bpm)) BPM")
        audioQueue.async { [weak self] in
            self?.musicalClock.tempo = bpm
        }
    }

    // MARK: - Metronome Scheduling

    private func scheduleMetronomeClicks() {
        guard let currentTime = engineManager.currentTime() else {
            print("⚠️ No current time from engine")
            return
        }

        let hostTime = currentTime.hostTime

        // For initial scheduling, start from beat 0 or continue from last
        let currentBeat = self.lastScheduledBeat
        let nextBeat = max(currentBeat, 0.0)

        print("🎵 Scheduling clicks: current=\(String(format: "%.2f", currentBeat)), next=\(String(format: "%.2f", nextBeat))")

        // Calculate time interval per beat in seconds
        let secondsPerBeat = 60.0 / musicalClock.tempo

        // Add small initial offset if this is first scheduling
        let initialOffset = (nextBeat == 0) ? 0.1 : 0.0  // 100ms delay for first click

        // Schedule lookahead beats
        for i in 0..<Int(lookaheadBeats) {
            let beat = nextBeat + Double(i)
            let secondsFromNow = initialOffset + (Double(i) * secondsPerBeat)

            // Convert seconds to host time (nanoseconds on iOS)
            let hostTimeOffset = UInt64(secondsFromNow * Double(NSEC_PER_SEC))
            let scheduledHostTime = hostTime + hostTimeOffset

            let audioTime = AVAudioTime(hostTime: scheduledHostTime)

            // Check if this is an accent (downbeat)
            let isAccent = Int(beat) % musicalClock.timeSignature.beatsPerBar == 0

            print("   🔔 Click scheduled at beat \(Int(beat)) (accent: \(isAccent), in \(String(format: "%.2f", secondsFromNow))s)")
            metronome.scheduleClick(at: audioTime, isAccent: isAccent)
        }

        lastScheduledBeat = nextBeat + lookaheadBeats
        print("✅ Scheduled \(Int(lookaheadBeats)) clicks, lastScheduled=\(String(format: "%.2f", lastScheduledBeat))")

        // Schedule next batch after these play (for continuous playback)
        if nextBeat < 100 {  // Limit to 100 beats for Week 1 demo
            let scheduleNextDelay = secondsPerBeat * Double(lookaheadBeats) * 0.75  // Schedule next batch at 75% through current batch
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
        let currentBeat = playbackStartBeat + elapsedBeats

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
