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
        HStack(alignment: .bottom, spacing: 1.4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.6)
                    .fill(index < litBars ? litColor : Color.primary.opacity(0.22))
                    .frame(width: 3.0, height: barHeight(for: index))
            }
        }
        .frame(width: 12, height: 11, alignment: .bottomLeading)
        .fixedSize()
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: return 4.5
        case 1: return 7.0
        default: return 10.5
        }
    }
}