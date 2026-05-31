import SwiftUI

// MARK: - ZoneRingView
// Parametrisable circular arc ring used across Recovery, Sleep Performance, and Strain cards.
// Draws a faint track ring and a coloured progress arc using .round lineCap.
// The arc starts at the 12-o'clock position (rotationEffect -90°).
//
// Usage:
//   // Recovery (colour driven by zone):
//   ZoneRingView(value: 73, maxValue: 100, color: WH.Color.recoveryColor(forPercent: 73),
//                centerLabel: "73")
//
//   // Strain (fixed accent colour):
//   ZoneRingView(value: 14.2, maxValue: 21, color: WH.Color.strainAccent, centerLabel: "14.2")

struct ZoneRingView: View {

    // MARK: - Parameters

    /// Current value (e.g. 73.0 for recovery, 14.2 for strain)
    var value: Double
    /// Maximum value of the range (100.0 for recovery, 21.0 for strain)
    var maxValue: Double
    /// Arc fill colour — caller is responsible for choosing the right colour
    var color: Color
    /// Stroke width of both the track and the progress arc
    var lineWidth: CGFloat = 16
    /// Diameter of the ring view
    var size: CGFloat = 120
    /// Optional text shown in the centre of the ring (e.g. "87", "14.2")
    var centerLabel: String? = nil

    // MARK: - Derived

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Track ring — always visible, faint white
            Circle()
                .stroke(
                    WH.Color.ringTrack,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress arc — starts at 12 o'clock, fills clockwise
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Optional centre label
            if let label = centerLabel {
                Text(label)
                    .font(WH.Font.metricLarge(size: size * 0.27))
                    .foregroundStyle(WH.Color.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("ZoneRingView — examples") {
    HStack(spacing: 24) {
        VStack(spacing: 6) {
            ZoneRingView(value: 73, maxValue: 100,
                         color: WH.Color.recoveryGreen, centerLabel: "73")
            Text("Recovery Green")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }

        VStack(spacing: 6) {
            ZoneRingView(value: 25, maxValue: 100,
                         color: WH.Color.recoveryRed, centerLabel: "25")
            Text("Recovery Red")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }

        VStack(spacing: 6) {
            ZoneRingView(value: 14.2, maxValue: 21,
                         color: WH.Color.strainAccent, centerLabel: "14.2")
            Text("Strain")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
    }
    .padding(24)
    .background(WH.Color.background)
}
