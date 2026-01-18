//
//  AudioSessionManager.swift
//  SergeantMusic
//
//  Manages iOS audio session configuration for low-latency playback.
//

import Foundation
import AVFoundation

/// Manages iOS audio session configuration
///
/// Responsible for:
/// - Configuring audio session category and mode
/// - Setting buffer size for low latency
/// - Handling audio interruptions (phone calls, etc.)
/// - Background audio support
class AudioSessionManager {
    // MARK: - Properties

    private let session = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?

    /// Callback when playback should pause (e.g., phone call)
    var onInterruptionBegan: (() -> Void)?

    /// Callback when playback can resume
    var onInterruptionEnded: (() -> Void)?

    // MARK: - Lifecycle

    init() {
        registerForInterruptions()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Configuration

    /// Configure audio session for practice mode (low latency)
    /// - Throws: Audio session configuration errors
    func configureForPractice() throws {
        try session.setCategory(.playback, mode: .default, options: [])

        // Set preferred buffer size for low latency
        // 256 samples at 44.1kHz = ~5.8ms latency
        let preferredBufferDuration = 256.0 / 44100.0
        try session.setPreferredIOBufferDuration(preferredBufferDuration)

        // Set preferred sample rate
        try session.setPreferredSampleRate(44100.0)

        // Activate the session
        try session.setActive(true)
    }

    /// Configure audio session for casual listening (higher latency, save battery)
    /// - Throws: Audio session configuration errors
    func configureForCasual() throws {
        try session.setCategory(.playback, mode: .default, options: [])

        // Larger buffer for battery savings
        // 512 samples at 44.1kHz = ~11.6ms latency
        let preferredBufferDuration = 512.0 / 44100.0
        try session.setPreferredIOBufferDuration(preferredBufferDuration)

        try session.setPreferredSampleRate(44100.0)
        try session.setActive(true)
    }

    /// Activate the audio session
    /// - Throws: Audio session errors
    func activate() throws {
        try session.setActive(true)
    }

    /// Deactivate the audio session
    /// - Throws: Audio session errors
    func deactivate() throws {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Interruption Handling

    private func registerForInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio session interrupted (phone call, alarm, etc.)
            onInterruptionBegan?()

        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // System suggests we can resume playback
                onInterruptionEnded?()
            }

        @unknown default:
            break
        }
    }

    // MARK: - Route Change Handling

    /// Handle audio route changes (e.g., headphones plugged/unplugged)
    func registerForRouteChanges(callback: @escaping (AVAudioSession.RouteChangeReason) -> Void) {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }

            callback(reason)
        }
    }

    // MARK: - Information

    /// Current audio session buffer duration (actual, not preferred)
    var currentBufferDuration: TimeInterval {
        return session.ioBufferDuration
    }

    /// Current audio session sample rate (actual, not preferred)
    var currentSampleRate: Double {
        return session.sampleRate
    }

    /// Check if headphones are connected
    var isHeadphonesConnected: Bool {
        let outputs = session.currentRoute.outputs
        return outputs.contains { $0.portType == .headphones || $0.portType == .bluetoothA2DP }
    }
}
