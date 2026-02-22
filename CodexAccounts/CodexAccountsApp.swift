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

    /// SF Symbol name — changes with usage level
    private var iconName: String {
        guard let r = remaining else { return "chart.bar.fill" }
        if r > 66 { return "chart.bar.fill" }          // 3 bars
        if r > 33 { return "chart.bar.xaxis" }           // 2 bars
        return "chart.bar.xaxis"                          // 1 bar (dimmed)
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
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor)
            }

            if showPercent, let r = remaining {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }
}