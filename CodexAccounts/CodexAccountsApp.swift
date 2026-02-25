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

    private var statusColor: Color {
        guard let r = remaining else { return .primary }
        if r > 40 { return .green }
        if r > 15 { return .orange }
        return .red
    }

    private var litBars: Int {
        guard let r = remaining else { return 3 }
        if r >= 75 { return 3 }
        if r >= 40 { return 2 }
        return 1
    }

    private var showIcon: Bool {
        viewModel.menuBarDisplayMode != .percentOnly
    }

    private var showPercent: Bool {
        viewModel.menuBarDisplayMode != .iconOnly
    }

    var body: some View {
        HStack(spacing: 3) {
            if showIcon {
                UsageBarsIcon(litBars: litBars, litColor: statusColor)
                    .frame(width: 12, height: 11)
            }

            if showPercent, let r = remaining {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }
}

private struct UsageBarsIcon: View {
    let litBars: Int
    let litColor: Color

    var body: some View {
        Canvas { context, size in
            let barCount = 3
            let spacing: CGFloat = 1.4
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let barWidth = (size.width - totalSpacing) / CGFloat(barCount)

            let heights: [CGFloat] = [
                size.height * 0.42,
                size.height * 0.68,
                size.height * 1.0
            ]

            for index in 0..<barCount {
                let x = CGFloat(index) * (barWidth + spacing)
                let h = heights[index]
                let y = size.height - h
                let rect = CGRect(x: x, y: y, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.55)

                let color = index < litBars ? litColor : Color.primary.opacity(0.22)
                context.fill(path, with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}