//
//  AccountCardView.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct AccountCardView: View {
    let account: CodexAccount
    let usage: AccountUsage?
    let status: AccountStatus
    let onRefresh: () -> Void
    let onRemove: () -> Void
    let onReauth: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header: Email + Plan badge + Pin + Actions
            HStack(alignment: .center, spacing: 6) {
                // Status dot
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 5, height: 5)

                Text(account.email)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                PlanBadge(plan: account.planType)

                // Pin indicator
                if account.isPinned || isHovering {
                    Button(action: onTogglePin) {
                        Image(systemName: account.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 9))
                            .foregroundStyle(account.isPinned ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .help(account.isPinned ? "Unpin" : "Pin to top")
                }

                if isHovering {
                    Menu {
                        Button(action: onRefresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Button(action: onReauth) {
                            Label("Re-authenticate", systemImage: "key")
                        }
                        Divider()
                        Button(role: .destructive, action: onRemove) {
                            Label("Remove Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 16)
                    .transition(.opacity)
                }
            }

            // Content based on status
            if case .needsReauth = status {
                reauthPrompt
            } else if case .refreshing = status, usage == nil {
                loadingState
            } else if let usage {
                usageContent(usage)
            } else {
                loadingState
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBackground)
        .overlay(cardBorder)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Usage Content

    @ViewBuilder
    private func usageContent(_ usage: AccountUsage) -> some View {
        // Error banner
        if let error = usage.error {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }

        // Usage meters with dynamic labels
        VStack(alignment: .leading, spacing: 3) {
            UsageMeterView(
                label: usage.primaryWindowLabel,
                remainingPercent: usage.fiveHourRemainingPercent,
                resetAt: usage.fiveHourResetAt
            )

            UsageMeterView(
                label: usage.secondaryWindowLabel,
                remainingPercent: usage.weeklyRemainingPercent,
                resetAt: usage.weeklyResetAt
            )
        }

        // Reset times row — high contrast
        HStack(spacing: 0) {
            if let resetAt = usage.fiveHourResetAt {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 7))
                    Text(usage.primaryWindowLabel)
                        .font(.system(size: 9, weight: .medium))
                    Text(resetAt.resetDescription)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }

            if usage.fiveHourResetAt != nil && usage.weeklyResetAt != nil {
                Text("  ·  ")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }

            if let resetAt = usage.weeklyResetAt {
                HStack(spacing: 2) {
                    Text(usage.secondaryWindowLabel)
                        .font(.system(size: 9, weight: .medium))
                    Text(resetAt.resetDescription)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()
        }

        // Footer: Credits + Profile ID + Last updated
        HStack(spacing: 0) {
            if usage.isUnlimited {
                HStack(spacing: 2) {
                    Image(systemName: "infinity")
                        .font(.system(size: 7))
                    Text("Unlimited")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.purple)
            } else if usage.hasCredits, let balance = usage.creditsBalance {
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 8))
                    Text(String(format: "$%.2f", balance))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.green.opacity(0.8))
            }

            // Profile UUID
            if let shortId = account.shortAccountId {
                if usage.hasCredits || usage.isUnlimited {
                    Text("  ·  ")
                        .font(.system(size: 8))
                        .foregroundStyle(.quaternary)
                }
                Text(shortId)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .help(account.accountId ?? "")
            }

            Spacer()

            if case .refreshing = status {
                HStack(spacing: 3) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("...")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(usage.lastUpdated.relativeDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - States

    private var reauthPrompt: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("Token expired")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }

            Button(action: onReauth) {
                HStack(spacing: 3) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 8))
                    Text("Re-authenticate")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
            Text("Loading...")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    // MARK: - Styling

    private var statusDotColor: Color {
        switch status {
        case .active:
            if let usage {
                let lowest = usage.lowestRemainingPercent
                if lowest > 40 { return .green }
                else if lowest > 15 { return .orange }
                else { return .red }
            }
            return .green
        case .refreshing:
            return .blue
        case .needsReauth:
            return .orange
        case .error:
            return .red
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.fill.opacity(account.isPinned ? 0.6 : (isHovering ? 0.5 : 0.3)))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(borderColor, lineWidth: 0.5)
    }

    private var borderColor: Color {
        if account.isPinned {
            return .orange.opacity(0.25)
        }
        return isHovering ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)
    }
}

// MARK: - Plan Badge

struct PlanBadge: View {
    let plan: String

    var body: some View {
        Text(displayName)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(badgeGradient))
    }

    private var displayName: String {
        switch plan.lowercased() {
        case "pro": return "PRO"
        case "plus": return "PLUS"
        case "go": return "GO"
        case "free": return "FREE"
        case "team": return "TEAM"
        case "enterprise": return "ENT"
        case "edu", "education": return "EDU"
        default: return plan.uppercased()
        }
    }

    private var badgeGradient: LinearGradient {
        switch plan.lowercased() {
        case "pro":
            return LinearGradient(
                colors: [.purple, .indigo],
                startPoint: .leading, endPoint: .trailing
            )
        case "plus":
            return LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .leading, endPoint: .trailing
            )
        case "go":
            return LinearGradient(
                colors: [.teal, .mint],
                startPoint: .leading, endPoint: .trailing
            )
        case "team":
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading, endPoint: .trailing
            )
        case "enterprise":
            return LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .leading, endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [.gray, .gray.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }
}
