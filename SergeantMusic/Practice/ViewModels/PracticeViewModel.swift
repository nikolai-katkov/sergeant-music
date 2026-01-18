//
//  PracticeViewModel.swift
//  SergeantMusic
//
//  ViewModel for the practice screen.
//  Manages UI state and handles user interactions.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for practice session UI
///
/// Manages playback state, tempo, and current position display.
/// Communicates with PracticeCoordinator for audio operations.
@MainActor
class PracticeViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Is audio currently playing?
    @Published var isPlaying: Bool = false

    /// Current tempo in BPM
    @Published var tempo: Double = 120.0 {
        didSet {
            // Clamp to valid range
            let clampedTempo = max(40, min(240, tempo))
            if clampedTempo != tempo {
                tempo = clampedTempo
            }
            // Update coordinator tempo asynchronously to avoid recursion
            Task {
                await MainActor.run {
                    coordinator.setTempo(tempo)
                }
            }
        }
    }

    /// Current beat number (fractional, for display)
    @Published var currentBeat: Double = 0.0

    /// Current bar number (1-indexed for display)
    @Published var currentBar: Int = 1

    /// Current beat within bar (1-indexed for display)
    @Published var currentBeatInBar: Int = 1

    /// Current time signature
    @Published var timeSignature: TimeSignature = .fourFour

    // MARK: - Properties

    /// Reference to coordinator
    private let coordinator: PracticeCoordinator

    /// Cancellable for position updates
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Create practice view model
    /// - Parameter coordinator: Practice coordinator
    init(coordinator: PracticeCoordinator) {
        self.coordinator = coordinator
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to playback state updates from coordinator
        coordinator.$isPlaying
            .assign(to: &$isPlaying)

        // Subscribe to position updates from coordinator
        coordinator.playbackPositionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.currentBeat = position.beat
                self?.currentBar = position.bar + 1  // Convert to 1-indexed
                self?.currentBeatInBar = position.beatInBar
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Start playback
    func play() {
        coordinator.start()
    }

    /// Stop playback
    func pause() {
        coordinator.stop()
    }

    /// Toggle playback
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Reset playback to beginning
    func reset() {
        coordinator.reset()
    }

    /// Set tempo
    /// - Parameter bpm: Tempo in beats per minute
    func setTempo(_ bpm: Double) {
        self.tempo = bpm
    }

    // MARK: - Computed Properties

    /// Formatted tempo string
    var tempoText: String {
        return "\(Int(tempo)) BPM"
    }

    /// Formatted position string (Bar:Beat)
    var positionText: String {
        return "\(currentBar):\(currentBeatInBar)"
    }

    /// Time signature display string
    var timeSignatureText: String {
        return timeSignature.description
    }
}

// MARK: - Playback Position

/// Playback position for display
struct PlaybackPosition {
    let beat: Double
    let bar: Int
    let beatInBar: Int
}
