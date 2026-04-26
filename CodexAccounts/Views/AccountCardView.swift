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
    let usageDetailMode: AccountsViewModel.UsageDetailMode
    let status: AccountStatus
    let onRefresh: () -> Void
    let onRemove: () -> Void
    let onReauth: () -> Void
    let onTogglePin: () -> Void
    let onTestMessage: () -> Void
    let onDismissTestResult: () -> Void
    let isTestingMessage: Bool
    let testResult: TestMessageResult?

    @State private var isHovering = false

    private var showStateRow: Bool {
        if case .active = status, account.authState == .healthy { return false }
        return true
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.top, 9)
                    .padding(.horizontal, 10)

                if showStateRow {
                    stateRow
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                }

                if let usage {
                    usageRows(usage)
                        .padding(.horizontal, 10)
                        .padding(.bottom, isTestingMessage || testResult != nil ? 0 : 9)
                } else {
                    loadingRow
                        .padding(.horizontal, 10)
                        .padding(.bottom, isTestingMessage || testResult != nil ? 0 : 9)
                }

                if isTestingMessage {
                    testMessageLoadingRow
                        .padding(.horizontal, 10)
                        .padding(.bottom, 9)
                } else if let result = testResult {
                    testResultRow(result)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 9)
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .contextMenu {
            Button(action: onTogglePin) {
                Label(account.isPinned ? "Unpin" : "Pin to top",
                      systemImage: account.isPinned ? "pin.slash" : "pin")
            }
            Button(action: onTestMessage) {
                Label("Send test message", systemImage: "paperplane")
            }
            .disabled(isTestingMessage)
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
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(account.email)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if account.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }

            PlanBadge(plan: account.planType)

            if account.authState != .healthy {
                authBadge
            }

            contextMenu
                .opacity(isHovering ? 1 : 0)
        }
    }

    private var contextMenu: some View {
        Menu {
            Button(action: onTogglePin) {
                Label(account.isPinned ? "Unpin" : "Pin to top",
                      systemImage: account.isPinned ? "pin.slash" : "pin")
            }
            Button(action: onTestMessage) {
                Label("Send test message", systemImage: "paperplane")
            }
            .disabled(isTestingMessage)
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
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(isHovering ? 0.10 : 0))
                Image(systemName: "ellipsis")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .frame(width: 22, height: 18)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var authBadge: some View {
        Text(account.authState.displayName)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(authBadgeTextColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(authBadgeColor.opacity(0.18)))
            .overlay(
                Capsule()
                    .stroke(authBadgeColor.opacity(0.35), lineWidth: 0.7)
            )
    }

    // MARK: - Usage Rows

    @ViewBuilder
    private func usageRows(_ usage: AccountUsage) -> some View {
        // Usage bar + big % — no redundant label
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 4.5)
                        .fill(barGradient(for: usage.remainingPercent))
                        .frame(width: max(0, proxy.size.width * CGFloat(clampedPercent(usage.remainingPercent) / 100)))
                        .shadow(color: barGlowColor(for: usage.remainingPercent), radius: 4, y: 0)
                        .animation(.spring(duration: 0.5), value: usage.remainingPercent)
                }
            }
            .frame(height: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(clampedPercent(usage.remainingPercent)))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(percentColor(for: usage.remainingPercent))
                if usage.isWeeklyPrimary {
                    Text("Weekly")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }
            .frame(width: usage.isWeeklyPrimary ? 48 : 40, alignment: .trailing)
        }
        .padding(.top, 6)

        // Reset + meta row
        HStack(spacing: 0) {
            if let resetAt = usage.resetAt {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7.5))
                    Text("\(usage.isWeeklyPrimary ? "Weekly resets" : "Resets") \(resetAt.resetDescription)")
                        .font(.system(size: 9.5))
                }
                .foregroundStyle(Color.white.opacity(0.75))
            }

            Spacer()

            Group {
                if let shortId = account.shortAccountId {
                    Text(shortId)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.60))
                        .help(account.accountId ?? "")
                }
                if case .refreshing = status {
                    ProgressView().controlSize(.mini).padding(.leading, 3)
                } else {
                    Text("  \(usage.lastUpdated.relativeDescription)")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Color.white.opacity(0.60))
                }
            }
        }
        .padding(.top, 4)

        if let weeklyRemaining = usage.weeklyRemainingPercent, !usage.isWeeklyPrimary {
            weeklyUsageRow(weeklyRemaining: weeklyRemaining, weeklyResetAt: usage.weeklyResetAt)
                .padding(.top, 5)
        }

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

    @ViewBuilder
    private func weeklyUsageRow(weeklyRemaining: Double, weeklyResetAt: Date?) -> some View {
        switch usageDetailMode {
        case .compact:
            HStack(spacing: 4) {
                Text("Weekly \(Int(clampedPercent(weeklyRemaining)))% left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                if let weeklyResetAt {
                    Text("| resets \(weeklyResetAt.resetDescription)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.58))
                }
                Spacer()
            }
        case .detailed:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Weekly")
                        .font(.system(size: 8.5, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.60))
                    Spacer()
                    Text("\(Int(clampedPercent(weeklyRemaining)))% left")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(Color.white.opacity(0.09))
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(Color.white.opacity(0.42))
                            .frame(width: max(0, proxy.size.width * CGFloat(clampedPercent(weeklyRemaining) / 100)))
                    }
                }
                .frame(height: 6)

                if let weeklyResetAt {
                    Text("Resets \(weeklyResetAt.resetDescription)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.58))
                }
            }
        }
    }

    // MARK: - Reauth Row

    private var stateRow: some View {
        HStack(spacing: 6) {
            Image(systemName: stateIconName)
                .font(.system(size: 9))
                .foregroundStyle(stateColor)
            Text(stateText)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
            Spacer()
            if case .needsReauth = status {
                Button(action: onReauth) {
                    Text("Reauth")
                        .font(.system(size: 9.5, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
            }
        }
    }

    // MARK: - Loading Row

    private var loadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Loading...")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .padding(.top, 6)
    }

    // MARK: - Test Message Rows

    private var testMessageLoadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Sending test message…")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .padding(.top, 5)
    }

    private func testResultRow(_ result: TestMessageResult) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(result.success ? .green : .red)
                .padding(.top, 1)
            Text(result.message)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(result.success ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                .lineLimit(4)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            Button(action: onDismissTestResult) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .buttonStyle(.plain)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((result.success ? Color.green : Color.red).opacity(0.10))
        )
        .padding(.top, 5)
    }

    // MARK: - Colors

    private var accentColor: Color {
        switch status {
        case .active:
            guard let usage else { return .green }
            let r = usage.remainingPercent
            if r > 40 { return .green }
            else if r > 15 { return .orange }
            else { return .red }
        case .refreshing: return Color(red: 0.3, green: 0.55, blue: 1.0)
        case .stale: return .yellow
        case .degraded: return .orange
        case .needsReauth: return .orange
        case .error: return .red
        }
    }

    private var authBadgeColor: Color {
        switch account.authState {
        case .healthy: return .green
        case .stale: return .yellow
        case .degraded: return .orange
        case .needsReauth: return .red
        }
    }

    private var authBadgeTextColor: Color {
        account.authState == .healthy ? Color.green.opacity(0.95) : authBadgeColor.opacity(0.95)
    }

    private var cardBackground: some View {
        Group {
            if account.isPinned {
                Color.orange.opacity(isHovering ? 0.20 : 0.12)
            } else {
                Color.white.opacity(isHovering ? 0.12 : 0.07)
            }
        }
    }

    private var borderColor: Color {
        if account.isPinned { return Color.orange.opacity(isHovering ? 0.40 : 0.25) }
        return Color.white.opacity(isHovering ? 0.25 : 0.15)
    }

    private func barGradient(for remaining: Double) -> LinearGradient {
        if remaining > 40 {
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.82, blue: 0.52), Color(red: 0.10, green: 0.72, blue: 0.40)],
                startPoint: .leading, endPoint: .trailing)
        } else if remaining > 15 {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.18), Color(red: 1.0, green: 0.55, blue: 0.10)],
                startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.35, blue: 0.30), Color(red: 0.90, green: 0.22, blue: 0.20)],
                startPoint: .leading, endPoint: .trailing)
        }
    }

    private func barGlowColor(for remaining: Double) -> Color {
        if remaining > 40 { return Color(red: 0.18, green: 0.82, blue: 0.52).opacity(0.35) }
        else if remaining > 15 { return Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.30) }
        else { return Color(red: 1.0, green: 0.30, blue: 0.25).opacity(0.30) }
    }

    private func percentColor(for remaining: Double) -> Color {
        if remaining > 40 { return Color(red: 0.30, green: 0.90, blue: 0.55) }
        else if remaining > 15 { return Color(red: 1.0, green: 0.72, blue: 0.20) }
        else { return Color(red: 1.0, green: 0.40, blue: 0.40) }
    }

    private func clampedPercent(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private var stateIconName: String {
        switch status {
        case .active: return "checkmark.circle.fill"
        case .refreshing: return "arrow.triangle.2.circlepath.circle.fill"
        case .stale: return "clock.badge.exclamationmark"
        case .degraded: return "exclamationmark.circle.fill"
        case .needsReauth: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var stateColor: Color {
        switch status {
        case .active: return .green
        case .refreshing: return Color(red: 0.3, green: 0.55, blue: 1.0)
        case .stale: return .yellow
        case .degraded: return .orange
        case .needsReauth: return .orange
        case .error: return .red
        }
    }

    private var stateText: String {
        switch status {
        case .active:
            if let date = account.lastAuthValidationAt {
                return "Auth OK \(date.relativeDescription)"
            }
            return "Auth OK"
        case .refreshing:
            return "Refreshing session"
        case .stale:
            if let date = account.lastAuthValidationAt {
                return "Auth stale since \(date.relativeDescription)"
            }
            return "Auth stale"
        case .degraded:
            if let date = account.lastRefreshFailureAt {
                return "Refresh failing \(date.relativeDescription)"
            }
            return "Refresh failing"
        case .needsReauth:
            return "Session expired"
        case let .error(message):
            return message
        }
    }
}

// MARK: - Plan Badge

struct PlanBadge: View {
    let plan: String

    var body: some View {
        Text(displayName)
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
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
            return LinearGradient(colors: [Color(red: 0.65, green: 0.35, blue: 1.0), Color(red: 0.50, green: 0.25, blue: 0.92)], startPoint: .leading, endPoint: .trailing)
        case "plus":
            return LinearGradient(colors: [Color(red: 0.30, green: 0.55, blue: 1.0), Color(red: 0.15, green: 0.70, blue: 0.98)], startPoint: .leading, endPoint: .trailing)
        case "go":
            return LinearGradient(colors: [Color(red: 0.10, green: 0.72, blue: 0.58), Color(red: 0.05, green: 0.82, blue: 0.50)], startPoint: .leading, endPoint: .trailing)
        case "team":
            return LinearGradient(colors: [Color(red: 1.0, green: 0.60, blue: 0.15), Color(red: 1.0, green: 0.75, blue: 0.15)], startPoint: .leading, endPoint: .trailing)
        case "enterprise":
            return LinearGradient(colors: [Color(red: 1.0, green: 0.75, blue: 0.15), Color(red: 1.0, green: 0.60, blue: 0.15)], startPoint: .leading, endPoint: .trailing)
        case "free":
            return LinearGradient(colors: [Color(red: 0.45, green: 0.48, blue: 0.55), Color(red: 0.35, green: 0.38, blue: 0.45)], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [Color(white: 0.45), Color(white: 0.38)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
