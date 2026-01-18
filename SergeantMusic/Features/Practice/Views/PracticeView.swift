//
//  PracticeView.swift
//  SergeantMusic
//
//  Main practice screen UI.
//

import SwiftUI

/// Main practice view
struct PracticeView: View {
    // MARK: - Properties

    @StateObject var viewModel: PracticeViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Title
            Text("SergeantMusic")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Position Display
            VStack(spacing: 8) {
                Text("Bar: Beat")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(viewModel.positionText)
                    .font(.system(size: 60, weight: .medium, design: .monospaced))
            }

            // Time Signature
            Text(viewModel.timeSignatureText)
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            // Tempo Control
            VStack(spacing: 16) {
                Text("Tempo")
                    .font(.headline)

                Text(viewModel.tempoText)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))

                Slider(
                    value: $viewModel.tempo,
                    in: 40...240,
                    step: 1
                )
                .padding(.horizontal)

                HStack {
                    Text("40")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("240")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()

            Spacer()

            // Play/Pause Button
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

struct PracticeView_Previews: PreviewProvider {
    static var previews: some View {
        let coordinator = try! PracticeCoordinator()
        let viewModel = PracticeViewModel(coordinator: coordinator)

        return PracticeView(viewModel: viewModel)
    }
}
