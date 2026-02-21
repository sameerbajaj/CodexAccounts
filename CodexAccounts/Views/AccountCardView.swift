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
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                statusIndicator
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    headerRow
                    if case .needsReauth = status {
                        reauthRow
                    } else if let usage {
                        usageRows(usage)
                    } else {
                        loadingRow
                    }
                }
                .padding(.vertical, 11)
                .padding(.trailing, 12)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Status Indicator (left accent bar)

    private var statusIndicator: some View {
        Rectangle()
            .fill(statusBarColor)
            .frame(width: 3)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 9,
                    bottomLeadingRadius: 9,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(account.email)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 2)

            if account.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            PlanBadge(plan: account.planType)

            if isHovering {
                contextMenu
            }
        }
    }

    private var contextMenu: some View {
        Menu {
            Button(action: onTogglePin) {
                Label(account.isPinned ? "Unpin" : "Pin to top",
                      systemImage: account.isPinned ? "pin.slash" : "pin")
            }
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
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Usage Rows

    @ViewBuilder
    private func usageRows(_ usage: AccountUsage) -> some View {
        UsageMeterView(
            remainingPercent: usage.remainingPercent
        )
        .padding(.top, 5)

        HStack(spacing: 0) {
            // Reset time
            if let resetAt = usage.resetAt {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8))
                    Text("Resets \(resetAt.resetDescription)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Profile UUID + timestamp
            Group {
                if let shortId = account.shortAccountId {
                    Text(shortId)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .help(account.accountId ?? "")
                }
                if case .refreshing = status {
                    ProgressView().controlSize(.mini).padding(.leading, 3)
                } else {
                    Text("  \(usage.lastUpdated.relativeDescription)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.28))
                }
            }
        }
        .padding(.top, 5)

        // Error
        if let error = usage.error {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Reauth Row

    private var reauthRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Session expired")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onReauth) {
                Text("Re-authenticate")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.mini)
        }
        .padding(.top, 5)
    }

    // MARK: - Loading Row

    private var loadingRow: some View {
        HStack(spacing: 5) {
            ProgressView().controlSize(.small)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 5)
    }

    // MARK: - Computed Colors

    private var statusBarColor: Color {
        switch status {
        case .active:
            guard let usage else { return .green }
            let r = usage.remainingPercent
            if r > 40 { return .green }
            else if r > 15 { return .orange }
            else { return .red }
        case .refreshing: return .blue.opacity(0.6)
        case .needsReauth: return .orange
        case .error: return .red
        }
    }

    private var cardBackground: some View {
        Group {
            if account.isPinned {
                Color.orange.opacity(isHovering ? 0.07 : 0.04)
            } else {
                Color.primary.opacity(isHovering ? 0.06 : 0.03)
            }
        }
    }

    private var borderColor: Color {
        if account.isPinned { return .orange.opacity(0.18) }
        return Color.primary.opacity(isHovering ? 0.1 : 0.05)
    }
}

// MARK: - Usage Meter (stand-alone bar + % label)

struct UsageMeterView: View {
    let remainingPercent: Double

    private var clamped: Double { min(100, max(0, remainingPercent)) }

    var body: some View {
        HStack(spacing: 8) {
            Text("Codex Usage")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient)
                        .frame(width: max(0, proxy.size.width * CGFloat(clamped / 100)))
                        .animation(.spring(duration: 0.5), value: remainingPercent)
                }
            }
            .frame(height: 7)

            Text("\(Int(clamped))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(percentColor)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var barGradient: LinearGradient {
        if remainingPercent > 40 {
            return LinearGradient(colors: [.green, .green.opacity(0.7)],
                                  startPoint: .leading, endPoint: .trailing)
        } else if remainingPercent > 15 {
            return LinearGradient(colors: [.orange, .yellow.opacity(0.8)],
                                  startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red, .red.opacity(0.7)],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }

    private var percentColor: Color {
        if remainingPercent > 40 { return .green }
        else if remainingPercent > 15 { return .orange }
        else { return .red }
    }
}

// MARK: - Plan Badge

struct PlanBadge: View {
    let plan: String

    var body: some View {
        Text(displayName)
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
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
            return LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
        case "plus":
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case "go":
            return LinearGradient(colors: [.teal, .mint], startPoint: .leading, endPoint: .trailing)
        case "team":
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case "enterprise":
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
