//
//  AddAccountView.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct AddAccountView: View {
    let status: AccountsViewModel.AddAccountStatus
    let authCommand: String
    let prompt: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(statusIconColor)
                    .symbolEffect(.pulse, isActive: status == .watching)
            }
            .padding(.top, 8)

            Text(statusTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

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
                    .foregroundStyle(Color.white.opacity(0.75))
                    .font(.system(size: 12))
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Watching Content

    private var watchingContent: some View {
        VStack(spacing: 12) {
            Text(prompt)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Text("Run the following in your terminal:")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.64))
                .multilineTextAlignment(.center)

            CommandBlock(
                command: authCommand,
                description: "Sign in without logging out of your main Codex session"
            )

            Text("This uses a separate Codex auth folder and creates it if needed, so existing saved accounts are not revoked.")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.52))
                .multilineTextAlignment(.center)

            if status == .watching {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for authentication...")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.80))
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
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: email)

            Text("Account Detected!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)

            Text(email)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.90))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.fill.opacity(0.5))
                )
        }
    }

    // MARK: - Error Content

    private func errorContent(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.80))
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
        case .idle, .watching: return .blue
        case .detected: return .green
        case .error: return .red
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
    var description: String? = nil

    @State private var copied = false

    var body: some View {
        Button(action: copyCommand) {
            HStack(spacing: 8) {
                Text("$")
                    .foregroundStyle(.green.opacity(0.6))
                Text(command)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(copied ? Color.green : Color.white.opacity(0.65))
                    .animation(.easeInOut, value: copied)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.4), lineWidth: 0.5)
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
