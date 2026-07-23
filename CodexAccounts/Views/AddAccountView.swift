//
//  AddAccountView.swift
//  CodexAccounts
//

import SwiftUI

struct AddAccountView: View {
    let theme: ThemeColors
    let status: AccountsViewModel.AddAccountStatus
    let authCommand: String
    let prompt: String
    let onStartLogin: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusIconColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(statusIconColor)
                    .symbolEffect(.pulse, isActive: status == .watching)
            }
            .padding(.top, AppSpacing.xs)

            if !statusTitle.isEmpty {
                Text(statusTitle)
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
            }

            // Content based on status
            Group {
                switch status {
                case .idle, .watching:
                    watchingContent

                case let .detected(email):
                    detectedContent(email: email)

                case let .error(message):
                    errorContent(message: message)
                }
            }

            // Cancel button
            if status != .detected("") {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                    .font(AppTypography.body)
                    .padding(.bottom, AppSpacing.xs)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Watching Content

    private var watchingContent: some View {
        VStack(spacing: AppSpacing.md) {
            Text(prompt)
                .font(AppTypography.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onStartLogin) {
                Label("Open Codex Login", systemImage: "terminal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassButtonStyle(color: theme.accentPrimary))
            .help("Opens Terminal and runs Codex login using this app's isolated auth folder.")

            DisclosureGroup {
                VStack(spacing: AppSpacing.sm) {
                    Text("If the button does not open Terminal, run this fallback command:")
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)

                    CommandBlock(
                        command: authCommand,
                        theme: theme,
                        description: "Sign in without logging out of your main Codex session"
                    )
                }
                .padding(.top, 6)
            } label: {
                Text("Manual fallback")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(theme.textTertiary)
            }
            .tint(theme.textTertiary)

            Text("This uses an isolated Codex login for this app, so your normal terminal Codex session is not changed.")
                .font(AppTypography.caption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)

            if status == .watching {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for authentication…")
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Detected Content

    private func detectedContent(email: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(theme.successGreen)
                .symbolEffect(.bounce, value: email)

            Text("Account Detected!")
                .font(AppTypography.title)
                .foregroundStyle(theme.successGreen)

            Text(email)
                .font(AppTypography.mono)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                        .fill(theme.cardFill)
                )
        }
    }

    // MARK: - Error Content

    private func errorContent(message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.dangerRed)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Computed

    private var statusIcon: String {
        switch status {
        case .idle, .watching: return "person.badge.plus"
        case .detected: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var statusIconColor: Color {
        switch status {
        case .idle, .watching: return theme.accentPrimary
        case .detected: return theme.successGreen
        case .error: return theme.dangerRed
        }
    }

    private var statusTitle: String {
        switch status {
        case .idle, .watching: return "Add Codex Account"
        case .detected: return ""
        case .error: return "Error"
        }
    }
}

// MARK: - Command Block

struct CommandBlock: View {
    let command: String
    let theme: ThemeColors
    var description: String? = nil

    @State private var copied = false

    var body: some View {
        Button(action: copyCommand) {
            HStack(spacing: 8) {
                Text("$")
                    .font(AppTypography.mono)
                    .foregroundStyle(theme.successGreen)
                Text(command)
                    .font(AppTypography.mono)
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(copied ? theme.successGreen : theme.textTertiary)
                    .animation(.easeInOut, value: copied)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .fill(theme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .strokeBorder(theme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(description ?? "Click to copy")
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
