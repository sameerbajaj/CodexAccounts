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
    private let barHeights: [CGFloat] = [6.0, 9.0, 12.0]

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
            HStack(alignment: .bottom, spacing: 1.2) {
                ForEach(0..<3, id: \.self) { i in
                    let isLit = i < litBars
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(isLit ? 0.96 : 0.26))
                        .frame(width: 3.2, height: barHeights[i])
                }
            }
            .frame(width: 13.5, height: 12, alignment: .bottom)
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