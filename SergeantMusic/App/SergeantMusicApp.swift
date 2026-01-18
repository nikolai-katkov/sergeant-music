//
//  SergeantMusicApp.swift
//  SergeantMusic
//
//  App entry point.
//

import SwiftUI

@main
struct SergeantMusicApp: App {
    // MARK: - Properties

    /// Singleton coordinator (lives for app lifetime)
    @StateObject private var coordinator: PracticeCoordinator

    // MARK: - Initialization

    init() {
        // Initialize coordinator
        do {
            let coord = try PracticeCoordinator()
            _coordinator = StateObject(wrappedValue: coord)
        } catch {
            fatalError("Failed to initialize PracticeCoordinator: \(error)")
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            PracticeView(viewModel: PracticeViewModel(coordinator: coordinator))
        }
    }
}
