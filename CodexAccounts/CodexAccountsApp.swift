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

    private var barGlyph: String {
        switch litBars {
        case 3: return "▂▅█"
        case 2: return "▂▅▁"
        default: return "▂▁▁"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(barGlyph)
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(barColor)
                .fixedSize()

            if let r = remaining, viewModel.menuBarDisplayMode != .iconOnly {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(barColor)
            }
        }
        .fixedSize()
    }
}