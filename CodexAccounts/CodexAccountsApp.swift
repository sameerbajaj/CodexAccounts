//
//  CodexAccountsApp.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

@main
struct CodexAccountsApp: App {
    @State private var viewModel = AccountsViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let viewModel: AccountsViewModel

    private var remaining: Double? {
        viewModel.accounts.isEmpty ? nil : viewModel.menuBarRemaining
    }

    /// How many of the 3 bars should be lit (1–3), based on remaining %
    private var litBars: Int {
        guard let r = remaining else { return 3 }
        if r > 66 { return 3 }
        if r > 33 { return 2 }
        return 1
    }

    private var barColor: Color {
        guard let r = remaining else { return .primary }
        if r > 40 { return .green }
        if r > 15 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 4) {
            // Three-bar chart icon drawn with Canvas
            Canvas { ctx, size in
                let barCount = 3
                let gap: CGFloat = 1.5
                let totalGap = gap * CGFloat(barCount - 1)
                let barW: CGFloat = (size.width - totalGap) / CGFloat(barCount)
                let maxH = size.height

                // Heights increase left → right (25 %, 60 %, 100 %)
                let relativeHeights: [CGFloat] = [0.45, 0.72, 1.0]

                for i in 0..<barCount {
                    let x = CGFloat(i) * (barW + gap)
                    let barH = maxH * relativeHeights[i]
                    let y = maxH - barH
                    let rect = CGRect(x: x, y: y, width: barW, height: barH)
                    let path = Path(roundedRect: rect, cornerRadius: 1.5)

                    let isLit = i < litBars
                    let resolvedColor = isLit ? barColor : Color.primary.opacity(0.22)
                    ctx.fill(path, with: .color(resolvedColor))
                }
            }
            .frame(width: 14, height: 12)

            if let r = remaining, viewModel.menuBarDisplayMode != .iconOnly {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }
}
