//
//  MenuBarPopover.swift
//  CodexAccounts
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @State private var draggedPinnedAccountID: String? = nil
    @Namespace private var tabPickerNamespace

    private var theme: ThemeColors { viewModel.themeColors }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Tab content area
            Group {
                switch selectedTab {
                case .accounts:
                    accountsTabContent
                case .settings:
                    ScrollView {
                        settingsPanel
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.top, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.xs)
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: AppAnimation.quick), value: selectedTab)

            Divider()
                .background(theme.divider)
            footer
        }
        .frame(width: 360, height: popoverHeight)
        .background(theme.surfacePrimary)
        .environment(\.colorScheme, viewModel.selectedTheme.preferredColorScheme)
        .preferredColorScheme(viewModel.selectedTheme.preferredColorScheme)
        .task { viewModel.setup() }
    }

    private var accountsHeight: CGFloat {
        if viewModel.showingAddAccount || viewModel.accounts.isEmpty {
            return 440
        }
        let calculated = CGFloat(viewModel.accounts.count * 108 + 150)
        return min(640, max(480, calculated))
    }

    private var popoverHeight: CGFloat {
        switch selectedTab {
        case .accounts:
            return accountsHeight
        case .settings:
            return max(640, accountsHeight)
        }
    }

    // MARK: - Accounts Tab Content

    @ViewBuilder
    private var accountsTabContent: some View {
        if viewModel.showingAddAccount {
            AddAccountView(
                theme: theme,
                status: viewModel.addAccountStatus,
                authCommand: viewModel.addAccountCommand,
                prompt: viewModel.addAccountPrompt,
                onStartLogin: { viewModel.openCodexLogin() },
                onCancel: { viewModel.cancelAdding() }
            )
            .transition(.opacity)
        } else if viewModel.accounts.isEmpty {
            EmptyStateView(theme: theme, onAddAccount: { viewModel.startAddingAccount() })
                .transition(.opacity)
        } else {
            mainContent
                .transition(.opacity)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            // Row 1: Monospaced Logo + Title + Toolbar actions
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("CODEX")
                        .font(AppTypography.logoMono)
                        .foregroundStyle(theme.textPrimary)
                    Text("accounts")
                        .font(AppTypography.logoMonoLight)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                // Toolbar actions
                if selectedTab == .accounts && !viewModel.accounts.isEmpty {
                    HStack(spacing: 6) {
                        sortMenuButton
                        refreshButton
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)

            // Row 2: Segmented tab picker with sliding pill animation
            tabPicker
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)

            Divider().background(theme.divider)
        }
        .background(theme.surfaceSecondary.opacity(0.5))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(PopoverTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(tab.rawValue)
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? theme.textPrimary
                            : theme.textTertiary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(theme.cardFill)
                                .matchedGeometryEffect(id: "activeTab", in: tabPickerNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(theme.surfaceSecondary)
        )
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
                        .tint(theme.textPrimary)
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
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .fill(isActive ? theme.accentPrimary.opacity(0.16) : theme.cardFill)
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .stroke(isActive ? theme.accentPrimary.opacity(0.35) : theme.cardStroke, lineWidth: 0.75)
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? theme.accentPrimary : theme.textSecondary)
        }
        .frame(width: 30, height: 30)
    }

    private func toolbarButtonLabel(systemImage: String, text: String, isActive: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? theme.accentPrimary : theme.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .fill(isActive ? theme.accentPrimary.opacity(0.16) : theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .stroke(isActive ? theme.accentPrimary.opacity(0.35) : theme.cardStroke, lineWidth: 0.75)
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let update = viewModel.availableUpdate {
                    updateBanner(update)
                    Divider().background(theme.divider)
                }

                if let email = viewModel.detectedUntrackedEmail {
                    detectedBanner(email: email)
                    Divider().background(theme.divider)
                }

                VStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.displayedAccounts) { account in
                        let card = AccountCardView(
                            account: account,
                            usage: viewModel.usageData[account.id],
                            usageDetailMode: viewModel.usageDetailMode,
                            status: viewModel.accountStatuses[account.id] ?? .active,
                            theme: theme,
                            onRefresh: { Task { await viewModel.refreshAccount(account) } },
                            onRemove: { viewModel.removeAccount(account) },
                            onReauth: { viewModel.reauthAccount(account) },
                            onTogglePin: { viewModel.togglePin(account) },
                            onTestMessage: { viewModel.sendTestMessage(account) },
                            onDismissTestResult: { viewModel.dismissTestResult(account.id) },
                            onSetWeeklyAutoKickOverride: { viewModel.setWeeklyAutoKickOverride($0, for: account) },
                            onRetryAutoKickActivation: { Task { await viewModel.retryAutoKickActivation(for: account) } },
                            onRunDiagnosticExperiment: { exp in Task { await viewModel.runDiagnosticExperiment(for: account, experiment: exp) } },
                            isTestingMessage: viewModel.testMessageLoading.contains(account.id),
                            testResult: viewModel.testMessageResults[account.id],
                            weeklyAutoKickOverride: viewModel.weeklyAutoKickOverride(for: account),
                            weeklyAutoKickIndicator: viewModel.weeklyAutoKickIndicator(
                                for: account,
                                usage: viewModel.usageData[account.id]
                            )
                        )

                        if account.isPinned {
                            card
                                .onDrag {
                                    draggedPinnedAccountID = account.id
                                    return NSItemProvider(object: account.id as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: PinnedAccountDropDelegate(
                                        targetAccountID: account.id,
                                        draggedPinnedAccountID: $draggedPinnedAccountID,
                                        onMove: { draggedID, targetID in
                                            viewModel.movePinnedAccount(draggedID, before: targetID)
                                        }
                                    )
                                )
                        } else {
                            card
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
            }
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
                            .fill(theme.successGreen.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.successGreen)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(update.isRolling ? "New build available" : "Update available — v\(update.version)")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(theme.textPrimary)
                        Text("Installs automatically — no drag & drop")
                            .font(AppTypography.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    if update.downloadURL != nil {
                        Button { viewModel.installUpdate() } label: {
                            Text("Install")
                                .font(AppTypography.micro)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(theme.successGreen))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { NSWorkspace.shared.open(update.releaseURL) } label: {
                            Text("Download")
                                .font(AppTypography.micro)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(theme.successGreen))
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { viewModel.dismissUpdate() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

            case .downloading(let progress):
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downloading update…")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(theme.textPrimary)
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(theme.successGreen)
                    }
                    Text("\(Int(progress * 100))%")
                        .font(AppTypography.statSmall)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 32, alignment: .trailing)
                }

            case .installing:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Installing — app will relaunch…")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }

            case .failed(let message):
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.warningOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update failed")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(theme.textPrimary)
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        viewModel.selfUpdateState = .idle
                    } label: {
                        Text("Retry")
                            .font(AppTypography.micro)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(theme.warningOrange))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(theme.successGreen.opacity(0.08))
        .animation(.easeInOut(duration: AppAnimation.standard), value: viewModel.selfUpdateState)
    }

    // MARK: - Detected Banner

    private func detectedBanner(email: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(theme.accentPrimary)
            Text("Detected: \(email)")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Button("Add") { viewModel.addDetectedAccount() }
                .buttonStyle(GlassButtonStyle(color: theme.accentPrimary, isCompact: true))
            Button(action: { viewModel.dismissDetected() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(theme.accentPrimary.opacity(0.08))
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Theme selector card
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("THEME")
                    .font(AppTypography.micro)
                    .foregroundStyle(theme.textTertiary)

                HStack(spacing: AppSpacing.xs) {
                    ForEach(AppTheme.allCases) { t in
                        Button {
                            withAnimation(AppAnimation.spring()) {
                                viewModel.selectedTheme = t
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: t.iconName)
                                    .font(.system(size: 13))
                                Text(t.displayName)
                                    .font(AppTypography.micro)
                            }
                            .foregroundStyle(
                                viewModel.selectedTheme == t
                                    ? theme.accentPrimary
                                    : theme.textTertiary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                    .fill(viewModel.selectedTheme == t
                                          ? theme.accentPrimary.opacity(0.12)
                                          : theme.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                    .stroke(viewModel.selectedTheme == t ? theme.accentPrimary.opacity(0.35) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.md)
            .themedCard(theme: theme)

            // Settings sections
            settingsGroup(title: "Menu Bar Display") {
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

            settingsGroup(title: "Auto-Refresh") {
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

            settingsGroup(title: "Weekly Auto-Kick") {
                ForEach(WeeklyAutoKickMode.allCases) { mode in
                    settingsRow(
                        icon: mode.icon,
                        label: mode.rawValue,
                        description: mode.description,
                        isSelected: viewModel.weeklyAutoKickMode == mode
                    ) {
                        viewModel.weeklyAutoKickMode = mode
                    }
                }
            }

            settingsGroup(title: "Usage Detail Mode") {
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

            settingsGroup(title: "Updates") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check automatically on launch")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(theme.textPrimary)
                            Text("Detect new versions on startup")
                                .font(AppTypography.caption)
                                .foregroundStyle(theme.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.autoCheckUpdatesOnLaunch)
                            .labelsHidden()
                    }

                    HStack {
                        if let message = viewModel.updateCheckMessage {
                            Text(message)
                                .font(AppTypography.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.checkForUpdates(showUpToDateFeedback: true) }
                        } label: {
                            if viewModel.isCheckingForUpdates {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Check Now", systemImage: "arrow.clockwise")
                                    .font(AppTypography.captionMedium)
                            }
                        }
                        .buttonStyle(SubtleButtonStyle(theme: theme))
                        .disabled(viewModel.isCheckingForUpdates)
                    }
                }
                .padding(AppSpacing.md)
            }

            DiagnosticTraceView(
                traces: viewModel.diagnosticTraces,
                theme: theme,
                onClear: { viewModel.clearDiagnosticTraces() }
            )
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(AppTypography.micro)
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                content()
            }
            .padding(AppSpacing.xs)
            .themedCard(theme: theme)
        }
    }

    private func settingsRow(
        icon: String,
        label: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? theme.accentPrimary : theme.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accentPrimary)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .fill(isSelected ? theme.accentPrimary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button { viewModel.startAddingAccount() } label: {
                Label("Add Account", systemImage: "plus.circle.fill")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(theme.accentPrimary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("v\(currentVersion)")
                .font(AppTypography.mono)
                .foregroundStyle(theme.textTertiary)

            Button("Quit") { NSApp.terminate(nil) }
                .font(AppTypography.captionMedium)
                .foregroundStyle(theme.dangerRed.opacity(0.8))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(theme.surfaceSecondary.opacity(0.5))
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Drag and Drop Delegate

private struct PinnedAccountDropDelegate: DropDelegate {
    let targetAccountID: String
    @Binding var draggedPinnedAccountID: String?
    let onMove: (String, String) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedPinnedAccountID else { return false }
        onMove(draggedPinnedAccountID, targetAccountID)
        self.draggedPinnedAccountID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedPinnedAccountID, draggedPinnedAccountID != targetAccountID else { return }
        onMove(draggedPinnedAccountID, targetAccountID)
        self.draggedPinnedAccountID = targetAccountID
    }

    func dropExited(info: DropInfo) {}
}
