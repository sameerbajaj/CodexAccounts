//
//  AccountsViewModel.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
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
    var sortMode: SortMode = .pinned {
        didSet {
            UserDefaults.standard.set(sortMode.rawValue, forKey: "sortMode")
            frozenAccountOrder = nil
        }
    }
    var availableUpdate: UpdateInfo? = nil
    var isCheckingForUpdates = false
    var updateCheckMessage: String? = nil
    var selfUpdateState: SelfUpdateState = .idle
    var testMessageResults: [String: TestMessageResult] = [:]
    var testMessageLoading: Set<String> = []
    var lastSessionAuditAt: Date? = nil

    // Stored so @Observable tracks changes and SwiftUI re-renders immediately
    var menuBarDisplayMode: MenuBarDisplayMode = .iconAndPercent {
        didSet { UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }
    var refreshInterval: RefreshInterval = .fiveMin {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "refreshInterval")
            restartAutoRefresh()
        }
    }
    var usageDetailMode: UsageDetailMode = .compact {
        didSet { UserDefaults.standard.set(usageDetailMode.rawValue, forKey: "usageDetailMode") }
    }
    var autoCheckUpdatesOnLaunch: Bool = true {
        didSet { UserDefaults.standard.set(autoCheckUpdatesOnLaunch, forKey: "autoCheckUpdatesOnLaunch") }
    }

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

    enum AddAccountStatus: Equatable {
        case idle
        case watching
        case detected(String)
        case error(String)
    }

    enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
        case iconAndPercent = "Icon + %"
        case iconOnly = "Icon Only"
        case percentOnly = "% Only"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .iconAndPercent: return "chart.bar.doc.horizontal"
            case .iconOnly: return "chart.bar.fill"
            case .percentOnly: return "number"
            }
        }

        var description: String {
            switch self {
            case .iconAndPercent: return "Three-bar icon with remaining %"
            case .iconOnly: return "Three-bar icon only, no number"
            case .percentOnly: return "Just the remaining %, no icon"
            }
        }
    }

    enum RefreshInterval: String, CaseIterable, Identifiable {
        case twoMin = "2 minutes"
        case fiveMin = "5 minutes"
        case manual = "Manual only"

        var id: String { rawValue }

        var seconds: TimeInterval? {
            switch self {
            case .twoMin: return 120
            case .fiveMin: return 300
            case .manual: return nil
            }
        }

        var icon: String {
            switch self {
            case .twoMin: return "bolt.fill"
            case .fiveMin: return "clock"
            case .manual: return "hand.tap"
            }
        }

        var description: String {
            switch self {
            case .twoMin: return "Top account only, every 2 min"
            case .fiveMin: return "All accounts every 5 min"
            case .manual: return "Only when you tap refresh"
            }
        }
    }

    enum UsageDetailMode: String, CaseIterable, Identifiable {
        case compact = "Compact"
        case detailed = "Detailed"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .compact: return "text.alignleft"
            case .detailed: return "chart.bar.xaxis"
            }
        }

        var description: String {
            switch self {
            case .compact: return "Primary bar + concise weekly line"
            case .detailed: return "Adds a mini weekly meter and extra context"
            }
        }
    }

    // MARK: - Private

    private var hasSetup = false
    private var refreshTimer: Timer?
    private var tokenAuditTimer: Timer?
    private let syncWatcher = AuthFileWatcher()
    private let addAccountWatcher = AuthFileWatcher()
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var frozenAccountOrder: [String]? = nil
    private var activeRefreshCount = 0
    private var isAuditingSessions = false

    private let tokenAuditInterval: TimeInterval = 600
    private let tokenRefreshMaxAge: TimeInterval = 45 * 60
    private let staleSessionThreshold: TimeInterval = 55 * 60
    private let resumeAuditGapThreshold: TimeInterval = 20 * 60

    // MARK: - Init

    init() {
        if let raw = UserDefaults.standard.string(forKey: "menuBarDisplayMode"),
           let mode = MenuBarDisplayMode(rawValue: raw) {
            menuBarDisplayMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: "refreshInterval"),
           let interval = RefreshInterval(rawValue: raw) {
            refreshInterval = interval
        }
        if let raw = UserDefaults.standard.string(forKey: "usageDetailMode"),
           let mode = UsageDetailMode(rawValue: raw) {
            usageDetailMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: "sortMode"),
           let mode = SortMode(rawValue: raw) {
            sortMode = mode
        }
        if UserDefaults.standard.object(forKey: "autoCheckUpdatesOnLaunch") != nil {
            autoCheckUpdatesOnLaunch = UserDefaults.standard.bool(forKey: "autoCheckUpdatesOnLaunch")
        }
    }

    // MARK: - Computed

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
                return ra < rb
            }
        case .recentActivity:
            sortedUnpinned = unpinned.sorted { a, b in
                let da = usageData[a.id]?.lastActivityAt ?? .distantPast
                let db = usageData[b.id]?.lastActivityAt ?? .distantPast
                return da > db
            }
        }

        return pinned + sortedUnpinned
    }

    var displayedAccounts: [CodexAccount] {
        let current = sortedAccounts
        guard activeRefreshCount > 0, let frozenAccountOrder else {
            return current
        }

        let accountsByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let frozenIDs = Set(frozenAccountOrder)
        let frozen = frozenAccountOrder.compactMap { accountsByID[$0] }
        let remaining = current.filter { !frozenIDs.contains($0.id) }
        return frozen + remaining
    }

    var topAccountRemaining: Double? {
        guard let top = sortedAccounts.first else { return nil }
        return usageData[top.id]?.remainingPercent
    }

    var menuBarRemaining: Double? {
        topAccountRemaining
    }

    var statusColor: Color {
        guard let val = menuBarRemaining ?? topAccountRemaining else { return .secondary }
        if val > 40 { return .green }
        if val > 15 { return .orange }
        return .red
    }

    // MARK: - Setup

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true

        accounts = AccountStore.load().map(normalizedAccountOnLoad)
        applyAccountStates()
        syncCurrentAuthFile()

        if accounts.isEmpty, let account = CodexAPIService.readAuthFile() {
            accounts.append(account)
            persistAccounts()
            detectedUntrackedEmail = nil
        }

        startLifecycleObservers()
        startAuthFileSync()
        startAutoRefresh()
        startTokenAudit()

        Task {
            await auditAllSessions(trigger: .startup)
            await refreshAll(trigger: .manualRefresh)
        }

        if autoCheckUpdatesOnLaunch {
            Task { await checkForUpdates(showUpToDateFeedback: false) }
        }
    }

    // MARK: - Refresh

    func refreshAll() async {
        await refreshAll(trigger: .manualRefresh)
    }

    func refreshAll(trigger: CodexAPIService.AuditTrigger) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for account in accounts {
            await refreshAccount(account, trigger: trigger)
        }
    }

    func refreshAccount(_ account: CodexAccount) async {
        await refreshAccount(account, trigger: .manualRefresh)
    }

    func refreshAccount(_ account: CodexAccount, trigger: CodexAPIService.AuditTrigger) async {
        beginRefreshCycle()
        defer { endRefreshCycle() }

        accountStatuses[account.id] = .refreshing
        let previousUsage = usageData[account.id]
        var accountForUsage = currentAccount(id: account.id) ?? account

        do {
            let audit = try await CodexAPIService.auditSession(
                for: accountForUsage,
                trigger: trigger,
                maxTokenAge: tokenRefreshMaxAge,
                staleAfter: staleSessionThreshold
            )
            accountForUsage = mergeAccount(audit.account)
        } catch let error as CodexAPIService.APIError {
            let failed = CodexAPIService.markRefreshFailure(for: accountForUsage, error: error)
            accountForUsage = mergeAccount(failed)

            if error == .unauthorized {
                setUsageError("Token expired. Please re-authenticate.", for: account.id)
                accountStatuses[account.id] = .needsReauth
                return
            }
        } catch {
            let failed = CodexAPIService.markRefreshFailure(
                for: accountForUsage,
                error: .networkError(error.localizedDescription)
            )
            accountForUsage = mergeAccount(failed)
        }

        do {
            let result = try await CodexAPIService.fetchUsageWithRefresh(for: accountForUsage, previous: previousUsage)
            var newUsage = result.usage
            if let prev = previousUsage, prev.usedPercent != newUsage.usedPercent {
                newUsage.lastActivityAt = Date()
            } else {
                newUsage.lastActivityAt = previousUsage?.lastActivityAt
            }
            usageData[account.id] = newUsage

            let persisted = mergeAccount(result.updatedAccount ?? CodexAPIService.markUsageSuccess(for: accountForUsage))
            accountStatuses[account.id] = status(for: persisted)
        } catch let error as CodexAPIService.APIError where error == .unauthorized {
            let failed = CodexAPIService.markRefreshFailure(for: accountForUsage, error: error)
            let persisted = mergeAccount(failed)
            setUsageError("Token expired. Please re-authenticate.", for: account.id)
            accountStatuses[account.id] = status(for: persisted)
        } catch {
            accountStatuses[account.id] = .error(error.localizedDescription)
            setUsageError(error.localizedDescription, for: account.id)
        }
    }

    private func beginRefreshCycle() {
        if activeRefreshCount == 0 {
            frozenAccountOrder = sortedAccounts.map(\.id)
        }
        activeRefreshCount += 1
    }

    private func endRefreshCycle() {
        activeRefreshCount = max(0, activeRefreshCount - 1)
        if activeRefreshCount == 0 {
            frozenAccountOrder = nil
        }
    }

    // MARK: - Session Audit

    func auditAllSessions(trigger: CodexAPIService.AuditTrigger) async {
        guard !isAuditingSessions else { return }
        guard !accounts.isEmpty else { return }

        isAuditingSessions = true
        defer {
            isAuditingSessions = false
            lastSessionAuditAt = Date()
        }

        for account in accounts {
            let current = currentAccount(id: account.id) ?? account
            do {
                let result = try await CodexAPIService.auditSession(
                    for: current,
                    trigger: trigger,
                    maxTokenAge: tokenRefreshMaxAge,
                    staleAfter: staleSessionThreshold
                )
                let merged = mergeAccount(result.account)
                accountStatuses[account.id] = status(for: merged)
            } catch let error as CodexAPIService.APIError {
                let failed = CodexAPIService.markRefreshFailure(for: current, error: error)
                let merged = mergeAccount(failed)
                if error == .unauthorized {
                    setUsageError("Token expired. Please re-authenticate.", for: account.id)
                }
                accountStatuses[account.id] = status(for: merged)
            } catch {
                let failed = CodexAPIService.markRefreshFailure(
                    for: current,
                    error: .networkError(error.localizedDescription)
                )
                let merged = mergeAccount(failed)
                accountStatuses[account.id] = status(for: merged)
            }
        }
    }

    private func startTokenAudit() {
        tokenAuditTimer?.invalidate()
        tokenAuditTimer = Timer.scheduledTimer(withTimeInterval: tokenAuditInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.auditAllSessions(trigger: .timer)
            }
        }
    }

    private func handleLifecycleResume(trigger: CodexAPIService.AuditTrigger) {
        let now = Date()
        if let lastSessionAuditAt, now.timeIntervalSince(lastSessionAuditAt) < resumeAuditGapThreshold {
            return
        }

        markStaleAccounts(now: now)
        Task { await auditAllSessions(trigger: trigger) }
    }

    // MARK: - Update Checking

    func checkForUpdates(showUpToDateFeedback: Bool = false) async {
        isCheckingForUpdates = true
        if showUpToDateFeedback {
            updateCheckMessage = nil
        }

        let update = await UpdateChecker.check()

        isCheckingForUpdates = false
        availableUpdate = update

        if let update {
            updateCheckMessage = update.isRolling
                ? "New pre-release build available."
                : "New version v\(update.version) available."
        } else if showUpToDateFeedback {
            updateCheckMessage = "You’re up to date."
        }

        if showUpToDateFeedback {
            try? await Task.sleep(for: .seconds(4))
            if availableUpdate == nil {
                updateCheckMessage = nil
            }
        }
    }

    func dismissUpdate() {
        availableUpdate = nil
    }

    func installUpdate() {
        guard let update = availableUpdate, let dmgURL = update.downloadURL else { return }

        if update.isRolling, let ts = update.publishedAt {
            UpdateChecker.recordInstalledRollingTimestamp(ts)
        }

        Task {
            await SelfUpdater.update(dmgURL: dmgURL) { [weak self] state in
                Task { @MainActor in
                    self?.selfUpdateState = state
                }
            }
        }
    }

    // MARK: - Auto Refresh

    func restartAutoRefresh() {
        startAutoRefresh()
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard let interval = refreshInterval.seconds else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.refreshInterval == .twoMin, let top = self.sortedAccounts.first {
                    await self.refreshAccount(top, trigger: .timer)
                } else {
                    await self.refreshAll(trigger: .timer)
                }
            }
        }
    }

    // MARK: - Auth File Sync

    private func startAuthFileSync() {
        syncWatcher.onAuthFileChanged = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.syncCurrentAuthFile(trigger: .authFileSync)
            }
        }
        syncWatcher.start()
    }

    private func syncCurrentAuthFile(trigger: CodexAPIService.AuditTrigger = .startup) {
        guard let authAccount = CodexAPIService.readAuthFile() else { return }
        let existingIds = Set(accounts.map(\.id))

        if !existingIds.contains(authAccount.id) {
            detectedUntrackedEmail = authAccount.email
            return
        }

        let merged = mergeAuthSnapshot(authAccount)
        detectedUntrackedEmail = nil

        if trigger == .authFileSync {
            Task { await auditAllSessions(trigger: .authFileSync) }
        }

        accountStatuses[merged.id] = status(for: merged)
    }

    private func mergeAuthSnapshot(_ authAccount: CodexAccount) -> CodexAccount {
        guard let idx = accounts.firstIndex(where: { $0.id == authAccount.id }) else {
            accounts.append(authAccount)
            persistAccounts()
            return authAccount
        }

        var existing = accounts[idx]
        let snapshotIsNewer = shouldApplyAuthSnapshot(authAccount, over: existing)

        if authAccount.planType.lowercased() != "unknown" {
            existing.planType = authAccount.planType
        }
        if let accountId = authAccount.accountId, !accountId.isEmpty {
            existing.accountId = accountId
        }

        if snapshotIsNewer {
            let tokensChanged = authAccount.accessToken != existing.accessToken
                || authAccount.refreshToken != existing.refreshToken
                || authAccount.idToken != existing.idToken

            existing.accessToken = authAccount.accessToken
            existing.refreshToken = authAccount.refreshToken
            existing.idToken = authAccount.idToken
            existing.lastTokenRefresh = authAccount.lastTokenRefresh ?? existing.lastTokenRefresh
            existing.lastSuccessfulTokenRefreshAt = authAccount.lastSuccessfulTokenRefreshAt
                ?? authAccount.lastTokenRefresh
                ?? existing.lastSuccessfulTokenRefreshAt

            if tokensChanged || existing.authState == .needsReauth {
                existing.authState = .healthy
                existing.lastRefreshFailureAt = nil
                existing.consecutiveRefreshFailures = 0
            }
        }

        accounts[idx] = existing
        persistAccounts()
        return existing
    }

    private func shouldApplyAuthSnapshot(_ snapshot: CodexAccount, over existing: CodexAccount) -> Bool {
        if existing.accessToken.isEmpty || existing.refreshToken.isEmpty {
            return true
        }

        let tokensChanged = snapshot.accessToken != existing.accessToken
            || snapshot.refreshToken != existing.refreshToken
            || snapshot.idToken != existing.idToken

        let snapshotRefreshAt = snapshot.lastSuccessfulTokenRefreshAt ?? snapshot.lastTokenRefresh
        let existingRefreshAt = existing.lastSuccessfulTokenRefreshAt ?? existing.lastTokenRefresh

        switch (snapshotRefreshAt, existingRefreshAt) {
        case let (snapshotDate?, existingDate?):
            if snapshotDate >= existingDate {
                return true
            }
            return existing.authState == .needsReauth && tokensChanged
        case (_?, nil):
            return true
        case (nil, _?):
            return existing.authState == .needsReauth && tokensChanged
        case (nil, nil):
            return existing.authState == .needsReauth && tokensChanged
        }
    }

    // MARK: - Untracked Account Detection

    func addDetectedAccount() {
        guard let account = CodexAPIService.readAuthFile() else { return }
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            persistAccounts()
            Task { await refreshAccount(account, trigger: .authFileSync) }
        } else {
            _ = mergeAuthSnapshot(account)
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

        addAccountWatcher.onAuthFileChanged = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleAddAccountAuthFileChange()
            }
        }
        addAccountWatcher.start()
    }

    func cancelAdding() {
        showingAddAccount = false
        addAccountStatus = .idle
        addAccountWatcher.stop()
    }

    private func handleAddAccountAuthFileChange() {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard let account = CodexAPIService.readAuthFile() else {
                addAccountStatus = .error("Could not read auth file. Try again.")
                return
            }

            if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                _ = mergeAuthSnapshot(account)
                addAccountStatus = .detected("\(accounts[idx].email) (updated)")
            } else {
                accounts.append(account)
                persistAccounts()
                addAccountStatus = .detected(account.email)
            }

            addAccountWatcher.stop()
            Task { await refreshAccount(account, trigger: .authFileSync) }

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
        persistAccounts()
    }

    func reauthAccount(_ account: CodexAccount) {
        startAddingAccount()
    }

    // MARK: - Pinning

    func togglePin(_ account: CodexAccount) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx].isPinned.toggle()
        persistAccounts()
    }

    // MARK: - Test Message

    func sendTestMessage(_ account: CodexAccount) {
        guard !testMessageLoading.contains(account.id) else { return }
        testMessageLoading.insert(account.id)
        testMessageResults.removeValue(forKey: account.id)

        Task {
            let result = await TestMessageService.send(account: account)
            await MainActor.run {
                testMessageLoading.remove(account.id)
                testMessageResults[account.id] = result
            }

            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                if testMessageResults[account.id]?.timestamp == result.timestamp {
                    testMessageResults.removeValue(forKey: account.id)
                }
            }
        }
    }

    func dismissTestResult(_ accountId: String) {
        testMessageResults.removeValue(forKey: accountId)
    }

    // MARK: - Auth UI Helpers

    func authStatusText(for account: CodexAccount) -> String {
        switch account.authState {
        case .healthy:
            if let date = account.lastAuthValidationAt {
                return "Auth OK \(date.relativeDescription)"
            }
            return "Auth OK"
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
        }
    }

    // MARK: - Internal Helpers

    private func normalizedAccountOnLoad(_ account: CodexAccount) -> CodexAccount {
        var normalized = account
        if normalized.lastSuccessfulTokenRefreshAt == nil {
            normalized.lastSuccessfulTokenRefreshAt = normalized.lastTokenRefresh
        }
        normalized = CodexAPIService.markStaleIfNeeded(
            for: normalized,
            staleAfter: staleSessionThreshold
        )
        return normalized
    }

    private func persistAccounts() {
        AccountStore.save(accounts)
    }

    private func currentAccount(id: String) -> CodexAccount? {
        accounts.first(where: { $0.id == id })
    }

    @discardableResult
    private func mergeAccount(_ account: CodexAccount) -> CodexAccount {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = preservedAccountIdentity(from: account, existing: accounts[idx])
            accountStatuses[account.id] = status(for: accounts[idx])
            persistAccounts()
            return accounts[idx]
        }

        let normalized = normalizedAccountOnLoad(account)
        accounts.append(normalized)
        accountStatuses[normalized.id] = status(for: normalized)
        persistAccounts()
        return normalized
    }

    private func preservedAccountIdentity(from account: CodexAccount, existing: CodexAccount) -> CodexAccount {
        let preserved = CodexAccount(
            email: account.email,
            planType: account.planType,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            idToken: account.idToken,
            accountId: account.accountId,
            lastTokenRefresh: account.lastTokenRefresh,
            lastSuccessfulUsageAt: account.lastSuccessfulUsageAt,
            lastSuccessfulTokenRefreshAt: account.lastSuccessfulTokenRefreshAt,
            lastRefreshAttemptAt: account.lastRefreshAttemptAt,
            lastRefreshFailureAt: account.lastRefreshFailureAt,
            consecutiveRefreshFailures: account.consecutiveRefreshFailures,
            authState: account.authState,
            addedAt: existing.addedAt,
            isPinned: existing.isPinned
        )
        return normalizedAccountOnLoad(preserved)
    }

    private func setUsageError(_ message: String, for accountID: String) {
        var usage = usageData[accountID] ?? AccountUsage.placeholder
        usage.error = message
        usage.lastUpdated = Date()
        usageData[accountID] = usage
    }

    private func applyAccountStates() {
        for account in accounts {
            accountStatuses[account.id] = status(for: account)
        }
    }

    private func status(for account: CodexAccount) -> AccountStatus {
        switch account.authState {
        case .healthy: return .active
        case .stale: return .stale
        case .degraded: return .degraded
        case .needsReauth: return .needsReauth
        }
    }

    private func markStaleAccounts(now: Date = Date()) {
        var changed = false
        for idx in accounts.indices {
            let updated = CodexAPIService.markStaleIfNeeded(
                for: accounts[idx],
                staleAfter: staleSessionThreshold,
                now: now
            )
            if updated.authState != accounts[idx].authState {
                accounts[idx] = updated
                accountStatuses[updated.id] = status(for: updated)
                changed = true
            }
        }
        if changed {
            persistAccounts()
        }
    }

    private func startLifecycleObservers() {
        guard lifecycleObservers.isEmpty else { return }

        lifecycleObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.handleLifecycleResume(trigger: .resume)
                }
            }
        )

        lifecycleObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.handleLifecycleResume(trigger: .appDidBecomeActive)
                }
            }
        )
    }
}
