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

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "chart.bar.fill")
                .symbolRenderingMode(.hierarchical)
            if !viewModel.accounts.isEmpty, let remaining = viewModel.lowestRemaining {
                Text("\(Int(remaining))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }
}
