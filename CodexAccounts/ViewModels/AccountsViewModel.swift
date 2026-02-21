//
//  AccountsViewModel.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation
import SwiftUI

@Observable
final class AccountsViewModel {
    // MARK: - Published State

    var accounts: [CodexAccount] = []
    var usageData: [String: AccountUsage] = [:]
    var accountStatuses: [String: AccountStatus] = [:]
    var isRefreshing = false
    var showingAddAccount = false
    var addAccountStatus: AddAccountStatus = .idle
    var detectedUntrackedEmail: String? = nil

    // MARK: - Private

    private var hasSetup = false
    private var refreshTimer: Timer?
    private let fileWatcher = AuthFileWatcher()

    // MARK: - Computed

    /// Lowest remaining percent across all accounts (for menu bar display)
    var lowestRemaining: Double? {
        let values = usageData.values.map(\.lowestRemainingPercent)
        return values.min()
    }

    /// Overall status color for the menu bar icon
    var statusColor: Color {
        guard let lowest = lowestRemaining else { return .secondary }
        if lowest > 40 { return .green }
        else if lowest > 15 { return .orange }
        else { return .red }
    }

    // MARK: - Add Account Status

    enum AddAccountStatus: Equatable {
        case idle
        case watching
        case detected(String)
        case error(String)
    }

    // MARK: - Setup

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true

        // Load saved accounts
        accounts = AccountStore.load()

        // Check if current auth.json has an account we're not tracking
        checkForUntrackedAccount()

        // Auto-add on first launch if empty
        if accounts.isEmpty, let account = CodexAPIService.readAuthFile() {
            accounts.append(account)
            AccountStore.save(accounts)
            detectedUntrackedEmail = nil
        }

        // Refresh all accounts
        Task { await refreshAll() }

        // Start auto-refresh every 5 minutes
        startAutoRefresh()
    }

    // MARK: - Refresh

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                let accountCopy = account
                group.addTask {
                    await self.refreshAccount(accountCopy)
                }
            }
        }
    }

    func refreshAccount(_ account: CodexAccount) async {
        accountStatuses[account.id] = .refreshing

        do {
            let result = try await CodexAPIService.fetchUsageWithRefresh(for: account)
            usageData[account.id] = result.usage

            // Update stored tokens if they were refreshed
            if let updated = result.updatedAccount {
                if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                    accounts[idx] = updated
                    AccountStore.save(accounts)
                }
            }

            // Update plan type from the identity
            accountStatuses[account.id] = .active

        } catch let error as CodexAPIService.APIError where error == .unauthorized {
            accountStatuses[account.id] = .needsReauth
            var usage = usageData[account.id] ?? AccountUsage.placeholder
            usage.error = "Token expired. Please re-authenticate."
            usage.lastUpdated = Date()
            usageData[account.id] = usage

        } catch {
            accountStatuses[account.id] = .error(error.localizedDescription)
            var usage = usageData[account.id] ?? AccountUsage.placeholder
            usage.error = error.localizedDescription
            usage.lastUpdated = Date()
            usageData[account.id] = usage
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.refreshAll()
            }
        }
    }

    // MARK: - Untracked Account Detection

    private func checkForUntrackedAccount() {
        guard let authAccount = CodexAPIService.readAuthFile() else { return }
        let existingIds = Set(accounts.map(\.id))

        if !existingIds.contains(authAccount.id) {
            detectedUntrackedEmail = authAccount.email
        } else {
            // Update tokens for existing account
            if let idx = accounts.firstIndex(where: { $0.id == authAccount.id }) {
                accounts[idx].accessToken = authAccount.accessToken
                accounts[idx].refreshToken = authAccount.refreshToken
                accounts[idx].idToken = authAccount.idToken
                accounts[idx].lastTokenRefresh = authAccount.lastTokenRefresh
                AccountStore.save(accounts)
            }
            detectedUntrackedEmail = nil
        }
    }

    func addDetectedAccount() {
        guard let account = CodexAPIService.readAuthFile() else { return }
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            AccountStore.save(accounts)
            Task { await refreshAccount(account) }
        }
        detectedUntrackedEmail = nil
    }

    func dismissDetected() {
        detectedUntrackedEmail = nil
    }

    // MARK: - Add Account Flow

    func startAddingAccount() {
        showingAddAccount = true
        addAccountStatus = .watching

        fileWatcher.onAuthFileChanged = { [weak self] in
            self?.handleAuthFileChange()
        }
        fileWatcher.start()
    }

    func cancelAdding() {
        showingAddAccount = false
        addAccountStatus = .idle
        fileWatcher.stop()
    }

    private func handleAuthFileChange() {
        // Small delay to let the file fully write
        Task {
            try? await Task.sleep(for: .milliseconds(500))

            guard let account = CodexAPIService.readAuthFile() else {
                addAccountStatus = .error("Could not read auth file. Try again.")
                return
            }

            let email = account.email

            if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                // Update existing account tokens
                accounts[idx].accessToken = account.accessToken
                accounts[idx].refreshToken = account.refreshToken
                accounts[idx].idToken = account.idToken
                accounts[idx].planType = account.planType
                accounts[idx].lastTokenRefresh = account.lastTokenRefresh
                addAccountStatus = .detected("\(email) (updated)")
            } else {
                // New account
                accounts.append(account)
                addAccountStatus = .detected(email)
            }

            AccountStore.save(accounts)
            fileWatcher.stop()

            // Fetch usage for the account
            Task { await refreshAccount(account) }

            // Auto-dismiss after showing confirmation
            try? await Task.sleep(for: .seconds(2))
            showingAddAccount = false
            addAccountStatus = .idle
        }
    }

    // MARK: - Account Management

    func removeAccount(_ account: CodexAccount) {
        accounts.removeAll { $0.id == account.id }
        usageData.removeValue(forKey: account.id)
        accountStatuses.removeValue(forKey: account.id)
        AccountStore.save(accounts)
    }

    func reauthAccount(_ account: CodexAccount) {
        startAddingAccount()
    }
}
