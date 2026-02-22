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
            // Three-bar icon using plain fixed-size rectangles (Canvas collapses in MenuBarExtra)
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<3, id: \.self) { i in
                    let isLit = i < litBars
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isLit ? barColor : Color.primary.opacity(0.22))
                        .frame(width: 3.5, height: barHeights[i])
                }
            }
            .frame(width: 14, height: 12, alignment: .bottom)

            if let r = remaining, viewModel.menuBarDisplayMode != .iconOnly {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }

    private let barHeights: [CGFloat] = [5.5, 8.5, 12.0]
}