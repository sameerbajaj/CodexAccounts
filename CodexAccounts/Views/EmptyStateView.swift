//
//  EmptyStateView.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct EmptyStateView: View {
    let onAddAccount: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            // Icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("No Accounts Yet")
                    .font(.system(size: 14, weight: .semibold))

                Text("Add your Codex accounts to\ntrack usage across all of them.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAddAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("Add First Account")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            // Hint
            VStack(spacing: 4) {
                Text("Make sure Codex CLI is installed:")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("npm i -g @openai/codex")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}
