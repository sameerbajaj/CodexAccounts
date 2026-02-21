//
//  UsageMeterView.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct UsageMeterView: View {
    let label: String
    let remainingPercent: Double
    let resetAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)

                // Progress bar
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary.opacity(0.6))

                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barGradient)
                            .frame(width: max(0, proxy.size.width * CGFloat(clampedPercent / 100)))
                            .animation(.easeInOut(duration: 0.6), value: remainingPercent)
                    }
                }
                .frame(height: 7)

                // Percentage
                Text("\(Int(clampedPercent))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(percentColor)
                    .frame(width: 32, alignment: .trailing)
            }

            // Reset countdown
            if let resetAt {
                Text("Resets \(resetAt.resetDescription)")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
                    .padding(.leading, 38)
            }
        }
    }

    // MARK: - Computed

    private var clampedPercent: Double {
        min(100, max(0, remainingPercent))
    }

    private var barGradient: LinearGradient {
        if remainingPercent > 40 {
            return LinearGradient(
                colors: [.green, .green.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        } else if remainingPercent > 15 {
            return LinearGradient(
                colors: [.orange, .yellow.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [.red, .red.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    private var percentColor: Color {
        if remainingPercent > 40 { return .green }
        else if remainingPercent > 15 { return .orange }
        else { return .red }
    }
}
