//
//  PracticeView.swift
//  SergeantMusic
//
//  Main practice screen UI.
//

import SwiftUI

// MARK: - SimpleSlider

/// Custom slider component that avoids iOS material effects
///
/// This slider replaces the native SwiftUI Slider to eliminate a visual artifact
/// where the system accent color (pink) briefly appears during drag gestures.
/// The native slider uses glass/material effects that can show transient colors
/// during animation transitions.
///
/// Features:
/// - Solid blue color without glass effects
/// - Smooth drag interaction with step-based value snapping
/// - Subtle scale animation on thumb when dragging
/// - No system accent color bleed-through
struct SimpleSlider: View {
    // MARK: - Properties

    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @State private var isDragging = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                // Active track
                Capsule()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * percentage, height: 4)

                // Thumb
                Circle()
                    .fill(Color.blue)
                    .frame(width: isDragging ? 32 : 28, height: isDragging ? 32 : 28)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .offset(x: geometry.size.width * percentage - (isDragging ? 16 : 14))
                    .animation(.spring(response: 0.3), value: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                isDragging = true
                                updateValue(width: geometry.size.width, dragX: drag.location.x)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(height: 44)
    }

    // MARK: - Private Helpers

    private var percentage: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func updateValue(width: CGFloat, dragX: CGFloat) {
        let newPercentage = min(max(0, dragX / width), 1)
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * newPercentage
        value = (rawValue / step).rounded() * step
    }
}

// MARK: - PracticeView

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

                SimpleSlider(
                    value: $viewModel.tempo,
                    range: 40...240,
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
