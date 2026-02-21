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

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Email + Plan badge + Actions
            HStack(alignment: .center, spacing: 8) {
                // Status dot
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.email)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                PlanBadge(plan: account.planType)

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
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
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
        .padding(12)
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
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }

        // Usage meters
        UsageMeterView(
            label: "5h",
            remainingPercent: usage.fiveHourRemainingPercent,
            resetAt: usage.fiveHourResetAt
        )

        UsageMeterView(
            label: "Week",
            remainingPercent: usage.weeklyRemainingPercent,
            resetAt: usage.weeklyResetAt
        )

        // Credits + Last updated row
        HStack(spacing: 0) {
            if usage.isUnlimited {
                HStack(spacing: 3) {
                    Image(systemName: "infinity")
                        .font(.system(size: 8))
                    Text("Unlimited")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.purple)
            } else if usage.hasCredits, let balance = usage.creditsBalance {
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 9))
                    Text(String(format: "$%.2f", balance))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.green.opacity(0.8))
            }

            Spacer()

            if case .refreshing = status {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Updating...")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(usage.lastUpdated.relativeDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - States

    private var reauthPrompt: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("Token expired")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }

            Button(action: onReauth) {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 9))
                    Text("Re-authenticate")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Loading usage data...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
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
        RoundedRectangle(cornerRadius: 10)
            .fill(.fill.opacity(isHovering ? 0.7 : 0.4))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(.separator.opacity(isHovering ? 0.5 : 0.25), lineWidth: 0.5)
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
