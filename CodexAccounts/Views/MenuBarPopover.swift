//
//  MenuBarPopover.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI
import AppKit

struct MenuBarPopover: View {
    @Bindable var viewModel: AccountsViewModel
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.showingAddAccount {
                AddAccountView(
                    status: viewModel.addAccountStatus,
                    hasExistingAccounts: !viewModel.accounts.isEmpty,
                    onCancel: { viewModel.cancelAdding() }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if viewModel.accounts.isEmpty {
                EmptyStateView(onAddAccount: { viewModel.startAddingAccount() })
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }

            if showingSettings {
                Divider()
                    .background(Color.white.opacity(0.12))
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Divider()
                .background(Color.white.opacity(0.12))
            footer
        }
        .frame(width: 360)
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingAddAccount)
        .animation(.easeInOut(duration: 0.2), value: viewModel.accounts.count)
        .animation(.easeInOut(duration: 0.2), value: showingSettings)
        .animation(.easeInOut(duration: 0.3), value: viewModel.availableUpdate?.version)
        .animation(.easeInOut(duration: 0.25), value: viewModel.selfUpdateState)
        .task { viewModel.setup() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
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
                }

                Spacer()

                if !viewModel.accounts.isEmpty {
                    Menu {
                        ForEach(AccountsViewModel.SortMode.allCases) { mode in
                            Button {
                                viewModel.sortMode = mode
                            } label: {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                            .overlay(
                                viewModel.sortMode == mode
                                    ? Image(systemName: "checkmark").padding(.trailing, 4)
                                    : nil,
                                alignment: .trailing
                            )
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10, weight: .medium))
                            Text(viewModel.sortMode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.80))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button(action: {
                        Task { await viewModel.refreshAll() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                            .animation(
                                viewModel.isRefreshing
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isRefreshing
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.02))

            if !viewModel.accounts.isEmpty {
                Divider().background(Color.white.opacity(0.12))
            }
        }
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
                ForEach(viewModel.sortedAccounts) { account in
                    AccountCardView(
                        account: account,
                        usage: viewModel.usageData[account.id],
                        status: viewModel.accountStatuses[account.id] ?? .active,
                        onRefresh: { Task { await viewModel.refreshAccount(account) } },
                        onRemove: { viewModel.removeAccount(account) },
                        onReauth: { viewModel.reauthAccount(account) },
                        onTogglePin: { viewModel.togglePin(account) }
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
                        .padding(.bottom, 10)
                }
            }
        }
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
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(showingSettings ? Color.accentColor : Color.white.opacity(0.75))
            }
            .buttonStyle(.plain)

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

