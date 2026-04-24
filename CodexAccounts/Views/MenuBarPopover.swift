//
//  MenuBarPopover.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI
import AppKit

// MARK: - Tab Enum

private enum PopoverTab: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .accounts: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MenuBarPopover: View {
    @Bindable var viewModel: AccountsViewModel
    @State private var selectedTab: PopoverTab = .accounts

    var body: some View {
        VStack(spacing: 0) {
            header

            // Tab content area — fixed switch, no layout-shifting animation
            Group {
                switch selectedTab {
                case .accounts:
                    accountsTabContent
                case .settings:
                    settingsPanel
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)

            Divider()
                .background(Color.white.opacity(0.12))
            footer
        }
        .frame(width: 360)
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task { viewModel.setup() }
    }

    // MARK: - Accounts Tab Content

    @ViewBuilder
    private var accountsTabContent: some View {
        if viewModel.showingAddAccount {
            AddAccountView(
                status: viewModel.addAccountStatus,
                hasExistingAccounts: !viewModel.accounts.isEmpty,
                authCommand: viewModel.addAccountCommand,
                onCancel: { viewModel.cancelAdding() }
            )
            .transition(.opacity)
        } else if viewModel.accounts.isEmpty {
            EmptyStateView(onAddAccount: { viewModel.startAddingAccount() })
                .transition(.opacity)
        } else {
            mainContent
                .transition(.opacity)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            // Row 1: Logo + Title + Toolbar actions
            HStack(spacing: 0) {
                // Logo + title — fixed, never wraps
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.3, green: 0.45, blue: 1.0),
                                             Color(red: 0.55, green: 0.25, blue: 0.95)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Codex Accounts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                // Toolbar actions — only show when on accounts tab with accounts
                if selectedTab == .accounts && !viewModel.accounts.isEmpty {
                    HStack(spacing: 6) {
                        sortMenuButton
                        refreshButton
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Row 2: Segmented tab picker
            tabPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.12))
        }
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(PopoverTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? Color.white
                            : Color.white.opacity(0.50)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                selectedTab == tab
                                    ? Color.white.opacity(0.12)
                                    : Color.clear
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var headerSubtitle: String {
        let count = viewModel.accounts.count
        guard count > 0 else { return "Track Codex usage from the menu bar" }
        return "\(count) account\(count == 1 ? "" : "s") connected"
    }

    private var sortMenuButton: some View {
        Menu {
            ForEach(AccountsViewModel.SortMode.allCases) { mode in
                Button {
                    viewModel.sortMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            toolbarButtonLabel(
                systemImage: currentSortSymbol,
                text: viewModel.sortMode.rawValue,
                isActive: viewModel.sortMode != .pinned
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Sort accounts: \(viewModel.sortMode.rawValue)")
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refreshAll() }
        } label: {
            ZStack {
                toolbarButtonLabel(systemImage: "arrow.clockwise")
                    .opacity(viewModel.isRefreshing ? 0 : 1)

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Color.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRefreshing)
        .help(viewModel.isRefreshing ? "Refreshing accounts" : "Refresh all accounts")
    }

    private var currentSortSymbol: String {
        switch viewModel.sortMode {
        case .pinned:
            return "pin"
        case .nearestReset:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .lowestUsage:
            return "chart.bar.fill"
        case .recentActivity:
            return "bolt.fill"
        }
    }

    private func toolbarButtonLabel(systemImage: String, isActive: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.08))
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Color.white.opacity(0.82))
        }
        .frame(width: 30, height: 30)
    }

    private func toolbarButtonLabel(systemImage: String, text: String, isActive: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? Color.accentColor : Color.white.opacity(0.90))
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let update = viewModel.availableUpdate {
                updateBanner(update)
                Divider().background(Color.white.opacity(0.12))
            }

            if let email = viewModel.detectedUntrackedEmail {
                detectedBanner(email: email)
                Divider().background(Color.white.opacity(0.12))
            }

            VStack(spacing: 5) {
                ForEach(viewModel.displayedAccounts) { account in
                    AccountCardView(
                        account: account,
                        usage: viewModel.usageData[account.id],
                        usageDetailMode: viewModel.usageDetailMode,
                        status: viewModel.accountStatuses[account.id] ?? .active,
                        onRefresh: { Task { await viewModel.refreshAccount(account) } },
                        onRemove: { viewModel.removeAccount(account) },
                        onReauth: { viewModel.reauthAccount(account) },
                        onTogglePin: { viewModel.togglePin(account) },
                        onTestMessage: { viewModel.sendTestMessage(account) },
                        onDismissTestResult: { viewModel.dismissTestResult(account.id) },
                        isTestingMessage: viewModel.testMessageLoading.contains(account.id),
                        testResult: viewModel.testMessageResults[account.id]
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Update Banner

    private func updateBanner(_ update: UpdateInfo) -> some View {
        VStack(spacing: 0) {
            switch viewModel.selfUpdateState {
            case .idle:
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(update.isRolling ? "New build available" : "Update available — v\(update.version)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Installs automatically — no drag & drop")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.80))
                    }
                    Spacer()
                    if update.downloadURL != nil {
                        Button { viewModel.installUpdate() } label: {
                            Text("Install")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { NSWorkspace.shared.open(update.releaseURL) } label: {
                            Text("Download")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { viewModel.dismissUpdate() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }

            case .downloading(let progress):
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downloading update…")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.green)
                    }
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .frame(width: 32, alignment: .trailing)
                }

            case .installing:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Installing — app will relaunch…")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }

            case .failed(let message):
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update failed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(message)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        viewModel.selfUpdateState = .idle
                    } label: {
                        Text("Retry")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.orange))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.07))
        .animation(.easeInOut(duration: 0.25), value: viewModel.selfUpdateState)
    }

    // MARK: - Detected Banner

    private func detectedBanner(email: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            Text("Detected: \(email)")
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button("Add") { viewModel.addDetectedAccount() }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            Button(action: { viewModel.dismissDetected() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(0.60))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSection(title: "Menu Bar Shows") {
                ForEach(AccountsViewModel.MenuBarDisplayMode.allCases) { mode in
                    settingsRow(
                        icon: mode.icon,
                        label: mode.rawValue,
                        description: mode.description,
                        isSelected: viewModel.menuBarDisplayMode == mode
                    ) {
                        viewModel.menuBarDisplayMode = mode
                    }
                }
            }

            Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 14)

            settingsSection(title: "Auto-Refresh") {
                ForEach(AccountsViewModel.RefreshInterval.allCases) { interval in
                    settingsRow(
                        icon: interval.icon,
                        label: interval.rawValue,
                        description: interval.description,
                        isSelected: viewModel.refreshInterval == interval
                    ) {
                        viewModel.refreshInterval = interval
                    }
                }
            }

            Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 14)

            settingsSection(title: "Usage Cards") {
                ForEach(AccountsViewModel.UsageDetailMode.allCases) { mode in
                    settingsRow(
                        icon: mode.icon,
                        label: mode.rawValue,
                        description: mode.description,
                        isSelected: viewModel.usageDetailMode == mode
                    ) {
                        viewModel.usageDetailMode = mode
                    }
                }
            }

            Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 14)

            settingsSection(title: "Updates") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check automatically on launch")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Detect new versions / latest builds on startup")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.autoCheckUpdatesOnLaunch)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.checkForUpdates(showUpToDateFeedback: true) }
                    } label: {
                        if viewModel.isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Check Now", systemImage: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .controlSize(.small)
                    .disabled(viewModel.isCheckingForUpdates)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                if let message = viewModel.updateCheckMessage {
                    Text(message)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .padding(.horizontal, 14)
                        .padding(.bottom, viewModel.availableUpdate != nil ? 6 : 10)
                }

                if let update = viewModel.availableUpdate, viewModel.selfUpdateState == .idle {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                        Text(update.isRolling ? "New build available" : "v\(update.version) available")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        if update.downloadURL != nil {
                            Button { viewModel.installUpdate() } label: {
                                Text("Install")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.green))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button { NSWorkspace.shared.open(update.releaseURL) } label: {
                                Text("Download")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.green))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.70))
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 2)

            VStack(spacing: 1) {
                content()
            }
            .padding(.bottom, 6)
        }
    }

    private func settingsRow(icon: String, label: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.white.opacity(0.50),
                            lineWidth: 1.5
                        )
                        .frame(width: 14, height: 14)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 7, height: 7)
                    }
                }

                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.80))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.90))
                    Text(description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: { viewModel.startAddingAccount() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add Account")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.40, green: 0.65, blue: 1.0))

                Spacer()

                Button {
                    NSWorkspace.shared.open(UpdateChecker.releasesPage)
                } label: {
                    Text("v\(UpdateChecker.currentVersion)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(viewModel.availableUpdate != nil
                                         ? Color.green
                                         : Color.white.opacity(0.60))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
