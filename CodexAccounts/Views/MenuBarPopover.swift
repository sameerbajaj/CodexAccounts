//
//  MenuBarPopover.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI

struct MenuBarPopover: View {
    @Bindable var viewModel: AccountsViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

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

            Divider().opacity(0.5)
            footer
        }
        .frame(width: 360)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingAddAccount)
        .animation(.easeInOut(duration: 0.2), value: viewModel.accounts.count)
        .task { viewModel.setup() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Codex Accounts")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if !viewModel.accounts.isEmpty {
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
                .help("Refresh all accounts")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Detected untracked account banner
            if let email = viewModel.detectedUntrackedEmail {
                detectedBanner(email: email)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.accounts) { account in
                        AccountCardView(
                            account: account,
                            usage: viewModel.usageData[account.id],
                            status: viewModel.accountStatuses[account.id] ?? .active,
                            onRefresh: {
                                Task { await viewModel.refreshAccount(account) }
                            },
                            onRemove: { viewModel.removeAccount(account) },
                            onReauth: { viewModel.reauthAccount(account) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 520)
        }
    }

    // MARK: - Detected Banner

    private func detectedBanner(email: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 10))
                .foregroundStyle(.blue)

            Text("Detected: **\(email)**")
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Button("Add") { viewModel.addDetectedAccount() }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

            Button(action: { viewModel.dismissDetected() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.08))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.startAddingAccount() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("Add Account")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Text("v1.0")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
