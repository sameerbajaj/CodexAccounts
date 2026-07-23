//
//  AccountCardView.swift
//  CodexAccounts
//

import SwiftUI

struct AccountCardView: View {
    let account: CodexAccount
    let usage: AccountUsage?
    let usageDetailMode: AccountsViewModel.UsageDetailMode
    let status: AccountStatus
    let theme: ThemeColors
    let onRefresh: () -> Void
    let onRemove: () -> Void
    let onReauth: () -> Void
    let onTogglePin: () -> Void
    let onTestMessage: () -> Void
    let onDismissTestResult: () -> Void
    let onSetWeeklyAutoKickOverride: (WeeklyAutoKickOverride) -> Void
    let isTestingMessage: Bool
    let testResult: TestMessageResult?
    let weeklyAutoKickOverride: WeeklyAutoKickOverride
    let weeklyAutoKickIndicator: AccountsViewModel.WeeklyAutoKickIndicator?

    @State private var isHovering = false

    private var showStateRow: Bool {
        if case .active = status, account.authState == .healthy { return false }
        return true
    }

    private var statusAccentColor: Color {
        if let usage {
            return theme.statusColor(remainingPercent: usage.remainingPercent, isLimitReached: usage.isLimitReached)
        }
        return theme.accentPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            headerRow

            if showStateRow {
                stateRow
            }

            if let usage {
                TimelineView(.periodic(from: Date(), by: 30)) { _ in
                    usageRows(usage)
                }
            } else {
                loadingRow
            }

            if isTestingMessage {
                testMessageLoadingRow
            } else if let result = testResult {
                testResultRow(result)
            }
        }
        .padding(AppSpacing.md)
        .themedCard(theme: theme, isHovered: isHovering, accentColor: account.isPinned ? theme.pinnedAccent : statusAccentColor)
        .onHover { isHovering = $0 }
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
            Menu("Weekly Auto-Kick") {
                Button(action: { onSetWeeklyAutoKickOverride(.inherit) }) {
                    HStack {
                        Text("Use Global Setting")
                        if weeklyAutoKickOverride == .inherit { Image(systemName: "checkmark") }
                    }
                }
                Button(action: { onSetWeeklyAutoKickOverride(.forceOn) }) {
                    HStack {
                        Text("Always Enable for This Account")
                        if weeklyAutoKickOverride == .forceOn { Image(systemName: "checkmark") }
                    }
                }
                Button(action: { onSetWeeklyAutoKickOverride(.forceOff) }) {
                    HStack {
                        Text("Always Disable for This Account")
                        if weeklyAutoKickOverride == .forceOff { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button(action: onReauth) {
                Label("Re-authenticate…", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive, action: onRemove) {
                Label("Remove Account", systemImage: "trash")
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(account.email)
                .font(AppTypography.headline)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if account.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.pinnedAccent)
                    .rotationEffect(.degrees(45))
                    .help("Pinned account")
            }

            if let indicator = weeklyAutoKickIndicator {
                Image(systemName: indicator.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(indicator.color)
                    .help(indicator.help)
            }

            Spacer()

            planBadge

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: AppAnimation.quick), value: isHovering)
        }
    }

    // MARK: - Plan Badge

    private var planBadge: some View {
        Text(account.planType.uppercased())
            .font(AppTypography.micro)
            .fontWeight(.heavy)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(theme.planBadgeGradient(for: account.planType))
            )
    }

    // MARK: - State Row

    private var stateRow: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 11))
                .foregroundStyle(statusColor)

            Text(statusMessage)
                .font(AppTypography.caption)
                .foregroundStyle(statusColor)
                .lineLimit(1)

            Spacer()

            if showReauthButton {
                Button("Reauth", action: onReauth)
                    .buttonStyle(GlassButtonStyle(color: theme.warningOrange, isCompact: true))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                .fill(statusColor.opacity(0.10))
        )
    }

    private var statusIcon: String {
        switch status {
        case .refreshing: return "arrow.clockwise"
        case .stale: return "clock.badge.exclamationmark"
        case .degraded: return "exclamationmark.triangle"
        case .needsReauth: return "lock.badge.exclamationmark"
        case .error: return "exclamationmark.circle"
        case .active: return "checkmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .refreshing: return theme.accentPrimary
        case .stale: return theme.warningOrange
        case .degraded: return theme.warningOrange
        case .needsReauth: return theme.warningOrange
        case .error: return theme.dangerRed
        case .active: return theme.successGreen
        }
    }

    private var statusMessage: String {
        switch status {
        case .refreshing: return "Refreshing usage data…"
        case .stale: return "Session data stale"
        case .degraded: return "Token refresh warning"
        case .needsReauth: return "Re-authentication required"
        case .error(let msg): return msg
        case .active: return "Healthy"
        }
    }

    private var showReauthButton: Bool {
        if case .needsReauth = status { return true }
        if case .degraded = status { return true }
        return account.authState == .needsReauth
    }

    // MARK: - Usage Rows

    @ViewBuilder
    private func usageRows(_ usage: AccountUsage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Primary progress meter
            primaryMeterView(usage)

            // Details row (UUID, live pulse, activity)
            detailsSubRow(usage)

            // Optional secondary weekly meter
            if usageDetailMode == .detailed, let weekly = usage.secondaryWindow {
                secondaryMeterView(weekly)
            }
        }
    }

    private func primaryMeterView(_ usage: AccountUsage) -> some View {
        let remaining = usage.remainingPercent
        let statusColor = theme.statusColor(remainingPercent: remaining, isLimitReached: usage.isLimitReached)
        let gradient = statusGradient(for: remaining, isLimitReached: usage.isLimitReached)

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.progressTrack)

                    Capsule()
                        .fill(gradient)
                        .frame(width: max(0, geo.size.width * (remaining / 100.0)))
                        .shadow(color: statusColor.opacity(0.35), radius: 4, y: 1)
                        .animation(.spring(duration: 0.5), value: remaining)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack {
                Text(String(format: "%.0f%%", remaining))
                    .font(AppTypography.statMedium)
                    .foregroundStyle(statusColor)
                    .contentTransition(.numericText())

                Text("remaining")
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textTertiary)

                Spacer()

                Text(resetCountdownText(usage))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func secondaryMeterView(_ window: UsageWindow) -> some View {
        let remaining = window.remainingPercent
        let statusColor = theme.statusColor(remainingPercent: remaining, isLimitReached: false)

        return HStack(spacing: AppSpacing.sm) {
            Text("Weekly")
                .font(AppTypography.caption)
                .foregroundStyle(theme.textTertiary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.progressTrack)
                    Capsule()
                        .fill(statusColor)
                        .frame(width: max(0, geo.size.width * (remaining / 100.0)))
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", remaining))
                .font(AppTypography.statSmall)
                .foregroundStyle(statusColor)
        }
        .padding(.top, 2)
    }

    private func detailsSubRow(_ usage: AccountUsage) -> some View {
        HStack(spacing: 6) {
            if let shortID = account.shortAccountId {
                Text(shortID)
                    .font(AppTypography.mono)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            PulsingDot(color: theme.successGreen)

            if let lastActivity = usage.lastActivityAt {
                Text(relativeTimeString(from: lastActivity))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func statusGradient(for remaining: Double, isLimitReached: Bool) -> LinearGradient {
        if isLimitReached || remaining <= 15 {
            return LinearGradient(
                colors: [theme.dangerRed, theme.dangerRed.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        } else if remaining <= 40 {
            return LinearGradient(
                colors: [theme.warningOrange, theme.warningOrange.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [theme.successGreen, theme.successGreen.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    private func resetCountdownText(_ usage: AccountUsage) -> String {
        guard let resetAt = usage.resetAt else { return "" }
        let now = Date()
        guard resetAt > now else { return "Resetting soon" }
        let diff = Int(resetAt.timeIntervalSince(now))
        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        return "\(hours)h ago"
    }

    // MARK: - Loading & Test Message Rows

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Loading usage data…")
                .font(AppTypography.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private var testMessageLoadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Sending test prompt…")
                .font(AppTypography.caption)
                .foregroundStyle(theme.accentPrimary)
        }
        .padding(.vertical, 4)
    }

    private func testResultRow(_ result: TestMessageResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(result.success ? theme.successGreen : theme.dangerRed)

            Text(result.message)
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismissTestResult) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                .fill((result.success ? theme.successGreen : theme.dangerRed).opacity(0.10))
        )
    }
}

// MARK: - PulsingDot

private struct PulsingDot: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .scaleEffect(isAnimating ? 1.4 : 1.0)
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
