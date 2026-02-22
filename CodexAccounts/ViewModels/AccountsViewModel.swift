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
    var sortMode: SortMode = .pinned

    // MARK: - Sort

    enum SortMode: String, CaseIterable, Identifiable {
        case pinned = "Pinned"
        case nearestReset = "Reset Soon"
        case lowestUsage = "Most Used"
        case recentActivity = "Recent Activity"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pinned: return "pin"
            case .nearestReset: return "clock"
            case .lowestUsage: return "chart.bar.xaxis"
            case .recentActivity: return "bolt"
            }
        }
    }

    // MARK: - Private

    private var hasSetup = false
    private var refreshTimer: Timer?
    private let fileWatcher = AuthFileWatcher()

    // MARK: - Computed

    /// Accounts sorted according to current sort mode (pinned always first)
    var sortedAccounts: [CodexAccount] {
        let pinned = accounts.filter(\.isPinned)
        let unpinned = accounts.filter { !$0.isPinned }

        let sortedUnpinned: [CodexAccount]
        switch sortMode {
        case .pinned:
            sortedUnpinned = unpinned.sorted { $0.addedAt < $1.addedAt }
        case .nearestReset:
            sortedUnpinned = unpinned.sorted { a, b in
                let ra = usageData[a.id]?.resetAt ?? .distantFuture
                let rb = usageData[b.id]?.resetAt ?? .distantFuture
                return ra < rb
            }
        case .lowestUsage:
            sortedUnpinned = unpinned.sorted { a, b in
                let ra = usageData[a.id]?.remainingPercent ?? 100
                let rb = usageData[b.id]?.remainingPercent ?? 100
                return ra < rb  // lowest remaining first = most used first
            }
        case .recentActivity:
            sortedUnpinned = unpinned.sorted { a, b in
                let da = usageData[a.id]?.lastActivityAt ?? .distantPast
                let db = usageData[b.id]?.lastActivityAt ?? .distantPast
                return da > db  // most recent first
            }
        }

        return pinned + sortedUnpinned
    }

    // MARK: - Menu Bar Display Mode

    enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
        case topAccount = "Top Account %"
        case lowestRemaining = "Lowest Remaining %"
        case iconOnly = "Icon Only"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .topAccount: return "Shows remaining % for the first account in current sort order"
            case .lowestRemaining: return "Shows the lowest remaining % across all accounts"
            case .iconOnly: return "Shows only the icon with no text"
            }
        }
    }

    var menuBarDisplayMode: MenuBarDisplayMode {
        get {
            let raw = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? ""
            return MenuBarDisplayMode(rawValue: raw) ?? .topAccount
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarDisplayMode")
        }
    }

    /// Remaining % for the top account in current sort order
    var topAccountRemaining: Double? {
        guard let top = sortedAccounts.first else { return nil }
        return usageData[top.id]?.remainingPercent
    }

    /// Remaining % shown in the menu bar based on user preference
    var menuBarRemaining: Double? {
        switch menuBarDisplayMode {
        case .topAccount:
            return topAccountRemaining
        case .lowestRemaining:
            let values = accounts.compactMap { usageData[$0.id]?.remainingPercent }
            return values.min()
        case .iconOnly:
            return nil
        }
    }

    /// Overall status color for the menu bar icon
    var statusColor: Color {
        guard let val = menuBarRemaining ?? topAccountRemaining else { return .secondary }
        if val > 40 { return .green }
        else if val > 15 { return .orange }
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
        let previousUsage = usageData[account.id]

        do {
            let result = try await CodexAPIService.fetchUsageWithRefresh(for: account)
            // Build usage with activity tracking
            var newUsage = result.usage
            if let prev = previousUsage, prev.usedPercent != newUsage.usedPercent {
                newUsage.lastActivityAt = Date()
            } else {
                newUsage.lastActivityAt = previousUsage?.lastActivityAt
            }
            usageData[account.id] = newUsage

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

    // MARK: - Pinning

    func togglePin(_ account: CodexAccount) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx].isPinned.toggle()
        AccountStore.save(accounts)
    }
}
