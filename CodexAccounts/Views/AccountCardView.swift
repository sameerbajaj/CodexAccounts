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
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 9,
                        bottomLeadingRadius: 9,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.top, 11)
                    .padding(.horizontal, 12)

                if case .needsReauth = status {
                    reauthRow
                        .padding(.horizontal, 12)
                        .padding(.bottom, 11)
                } else if let usage {
                    usageRows(usage)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 11)
                } else {
                    loadingRow
                        .padding(.horizontal, 12)
                        .padding(.bottom, 11)
                }
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

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(account.email)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if account.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }

            PlanBadge(plan: account.planType)

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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(width: 24, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Usage Rows

    @ViewBuilder
    private func usageRows(_ usage: AccountUsage) -> some View {
        // Usage bar + big % — no redundant label
        HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barGradient(for: usage.remainingPercent))
                        .frame(width: max(0, proxy.size.width * CGFloat(min(100, max(0, usage.remainingPercent)) / 100)))
                        .animation(.spring(duration: 0.5), value: usage.remainingPercent)
                }
            }
            .frame(height: 7)

            Text("\(Int(min(100, max(0, usage.remainingPercent))))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(percentColor(for: usage.remainingPercent))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.top, 8)

        // Reset + meta row
        HStack(spacing: 0) {
            if let resetAt = usage.resetAt {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8))
                    Text("Resets \(resetAt.resetDescription)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()

            Group {
                if let shortId = account.shortAccountId {
                    Text(shortId)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .help(account.accountId ?? "")
                }
                if case .refreshing = status {
                    ProgressView().controlSize(.mini).padding(.leading, 3)
                } else {
                    Text("  \(usage.lastUpdated.relativeDescription)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
        }
        .padding(.top, 5)

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
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
            Button(action: onReauth) {
                Text("Re-authenticate")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.mini)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading Row

    private var loadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(.top, 8)
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
        case .needsReauth: return .orange
        case .error: return .red
        }
    }

    private var cardBackground: some View {
        Group {
            if account.isPinned {
                Color(red: 1.0, green: 0.55, blue: 0.1)
                    .opacity(isHovering ? 0.12 : 0.07)
            } else {
                Color.white.opacity(isHovering ? 0.1 : 0.055)
            }
        }
    }

    private var borderColor: Color {
        if account.isPinned { return Color.orange.opacity(0.25) }
        return Color.white.opacity(isHovering ? 0.14 : 0.07)
    }

    private func barGradient(for remaining: Double) -> LinearGradient {
        if remaining > 40 {
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 0.45), Color(red: 0.1, green: 0.72, blue: 0.35)],
                startPoint: .leading, endPoint: .trailing)
        } else if remaining > 15 {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.65, blue: 0.1), Color(red: 1.0, green: 0.5, blue: 0.05)],
                startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.28, blue: 0.28), Color(red: 0.9, green: 0.18, blue: 0.18)],
                startPoint: .leading, endPoint: .trailing)
        }
    }

    private func percentColor(for remaining: Double) -> Color {
        if remaining > 40 { return Color(red: 0.2, green: 0.85, blue: 0.45) }
        else if remaining > 15 { return Color(red: 1.0, green: 0.65, blue: 0.1) }
        else { return Color(red: 1.0, green: 0.35, blue: 0.35) }
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
            return LinearGradient(colors: [Color(red: 0.58, green: 0.3, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.85)], startPoint: .leading, endPoint: .trailing)
        case "plus":
            return LinearGradient(colors: [Color(red: 0.25, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.65, blue: 0.95)], startPoint: .leading, endPoint: .trailing)
        case "go":
            return LinearGradient(colors: [Color(red: 0.1, green: 0.72, blue: 0.65), Color(red: 0.05, green: 0.82, blue: 0.55)], startPoint: .leading, endPoint: .trailing)
        case "team":
            return LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 1.0, green: 0.75, blue: 0.1)], startPoint: .leading, endPoint: .trailing)
        case "enterprise":
            return LinearGradient(colors: [Color(red: 1.0, green: 0.75, blue: 0.1), Color(red: 1.0, green: 0.55, blue: 0.1)], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [Color(white: 0.4), Color(white: 0.32)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
