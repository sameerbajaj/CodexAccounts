//
//  EmptyStateView.swift
//  CodexAccounts
//

import SwiftUI

struct EmptyStateView: View {
    let theme: ThemeColors
    let onAddAccount: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer().frame(height: AppSpacing.sm)

            // Icon with subtle accent glow circle
            ZStack {
                Circle()
                    .fill(theme.accentPrimary.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 30))
                    .foregroundStyle(theme.accentPrimary)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Accounts Yet")
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)

                Text("Add your Codex accounts to\ntrack usage across all of them.")
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAddAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("Add First Account")
                        .font(AppTypography.bodyMedium)
                }
            }
            .buttonStyle(GlassButtonStyle(color: theme.accentPrimary))

            // Hint
            VStack(spacing: 4) {
                Text("Make sure Codex CLI is installed:")
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textTertiary)
                Text("npm i -g @openai/codex")
                    .font(AppTypography.mono)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer().frame(height: AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
    }
}
