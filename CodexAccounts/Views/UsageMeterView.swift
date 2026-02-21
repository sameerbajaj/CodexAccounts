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
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
                .lineLimit(1)

            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.07))

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(barGradient)
                        .frame(width: max(0, proxy.size.width * CGFloat(clampedPercent / 100)))
                        .animation(.easeInOut(duration: 0.6), value: remainingPercent)
                }
            }
            .frame(height: 6)

            Text("\(Int(clampedPercent))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(percentColor)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Computed

    private var clampedPercent: Double {
        min(100, max(0, remainingPercent))
    }

    private var barGradient: LinearGradient {
        if remainingPercent > 40 {
            return LinearGradient(
                colors: [.green.opacity(0.85), .green.opacity(0.6)],
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
