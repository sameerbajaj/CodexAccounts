//
//  MenuBarPopover.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct MenuBarPopover: View {
    @Bindable var viewModel: AccountsViewModel
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.showingAddAccount {
                Divider().opacity(0.4)
                AddAccountView(
                    status: viewModel.addAccountStatus,
                    hasExistingAccounts: !viewModel.accounts.isEmpty,
                    onCancel: { viewModel.cancelAdding() }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if viewModel.accounts.isEmpty {
                Divider().opacity(0.4)
                EmptyStateView(onAddAccount: { viewModel.startAddingAccount() })
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }

            if showingSettings {
                Divider().opacity(0.4)
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Divider().opacity(0.4)
            footer
        }
        .frame(width: 360)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingAddAccount)
        .animation(.easeInOut(duration: 0.2), value: viewModel.accounts.count)
        .animation(.easeInOut(duration: 0.2), value: showingSettings)
        .task { viewModel.setup() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                // App icon + title
                HStack(spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Codex Accounts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if !viewModel.accounts.isEmpty {
                    // Sort picker
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
                                .font(.system(size: 10.5, weight: .medium))
                            Text(viewModel.sortMode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Sort accounts")

                    Button(action: {
                        Task { await viewModel.refreshAll() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                            .animation(
                                viewModel.isRefreshing
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isRefreshing
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Refresh all")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if !viewModel.accounts.isEmpty {
                Divider().opacity(0.4)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let email = viewModel.detectedUntrackedEmail {
                detectedBanner(email: email)
                Divider().opacity(0.4)
            }

            VStack(spacing: 6) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Detected Banner

    private func detectedBanner(email: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
            Text("Detected: \(email)")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
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
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 2) {
                ForEach(AccountsViewModel.MenuBarDisplayMode.allCases) { mode in
                    Button {
                        viewModel.menuBarDisplayMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .stroke(viewModel.menuBarDisplayMode == mode ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                if viewModel.menuBarDisplayMode == mode {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 7, height: 7)
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(mode.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(viewModel.menuBarDisplayMode == mode
                                      ? Color.accentColor.opacity(0.08)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.12), value: viewModel.menuBarDisplayMode)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { viewModel.startAddingAccount() }) {
                Label("Add Account", systemImage: "plus.circle.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(showingSettings ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Text("v1.0")
                .font(.system(size: 9))
                .foregroundStyle(Color.primary.opacity(0.22))
                .padding(.horizontal, 4)

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
