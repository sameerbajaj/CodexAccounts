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
    struct WeeklyAutoKickIndicator {
        let symbol: String
        let color: Color
        let help: String
    }

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
    var weeklyAutoKickMode: WeeklyAutoKickMode = .off {
        didSet {
            UserDefaults.standard.set(weeklyAutoKickMode.rawValue, forKey: "weeklyAutoKickMode")
            rebuildWeeklyAutoKickSchedule()
        }
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
    private var weeklyAutoKickTimer: Timer?
    private let syncWatcher = AuthFileWatcher()
    private let addAccountWatcher = AuthFileWatcher()
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var frozenAccountOrder: [String]? = nil
    private var weeklyAutoKickNextCheckAt: [String: Date] = [:]
    private var activeRefreshCount = 0
    private var isAuditingSessions = false
    private var isEvaluatingWeeklyAutoKick = false
    private var pendingReauthAccountID: String? = nil

    private let tokenAuditInterval: TimeInterval = 6 * 60 * 60
    private let tokenRefreshMaxAge: TimeInterval = 7 * 24 * 60 * 60
    private let tokenRefreshExpiryBuffer: TimeInterval = 24 * 60 * 60
    private let staleSessionThreshold: TimeInterval = 24 * 60 * 60
    private let resumeAuditGapThreshold: TimeInterval = 20 * 60
    private let weeklyAutoKickInterval: TimeInterval = 60
    private let weeklyAutoKickDelay: TimeInterval = 5 * 60
    private let weeklyAutoKickRetryDelay: TimeInterval = 3 * 60
    private let weeklyAutoKickActivationDelay: TimeInterval = 8
    private let weeklyAutoKickMaxAttempts = 3
    private let weeklyResetDisplayGrace: TimeInterval = 60
    private let weeklyAutoKickNearResetThreshold: TimeInterval = 24 * 60 * 60
    private let weeklyAutoKickSoonThreshold: TimeInterval = 60 * 60
    private let weeklyAutoKickFarInterval: TimeInterval = 12 * 60 * 60
    private let weeklyAutoKickNearResetInterval: TimeInterval = 60 * 60
    private let weeklyAutoKickSoonInterval: TimeInterval = 15 * 60
    private let importCodexHome = "\(NSHomeDirectory())/.codex-accounts-import"

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
        if let raw = UserDefaults.standard.string(forKey: "weeklyAutoKickMode"),
           let mode = WeeklyAutoKickMode(rawValue: raw) {
            weeklyAutoKickMode = mode
        }
    }

    // MARK: - Computed

    var sortedAccounts: [CodexAccount] {
        let pinned = accounts
            .filter(\.isPinned)
            .sorted { a, b in
                let ao = a.pinnedOrder ?? Int.max
                let bo = b.pinnedOrder ?? Int.max
                if ao != bo { return ao < bo }
                return a.addedAt < b.addedAt
            }
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

    var addAccountCommand: String {
        "mkdir -p \"$HOME/.codex-accounts-import\" && CODEX_HOME=\"$HOME/.codex-accounts-import\" codex auth"
    }

    var addAccountPrompt: String {
        if let pendingReauthAccountID,
           let account = currentAccount(id: pendingReauthAccountID)
        {
            return "Sign back into \(account.email) in the browser window that Codex opens."
        }
        return "Sign into the account you want to import in the browser window that Codex opens."
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
        normalizePinnedOrder()
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
        startWeeklyAutoKickTimer()

        Task {
            await auditAllSessions(trigger: .startup)
            await refreshAll(trigger: .manualRefresh)
            await evaluateWeeklyAutoKickCandidates()
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
                staleAfter: staleSessionThreshold,
                refreshBeforeExpiry: tokenRefreshExpiryBuffer
            )
            accountForUsage = mergeAccount(audit.account)
        } catch let error as CodexAPIService.APIError {
            let failedError: CodexAPIService.APIError = if error == .unauthorized {
                .networkError("Refresh token rejected")
            } else {
                error
            }

            let failed = CodexAPIService.markRefreshFailure(for: accountForUsage, error: failedError)
            accountForUsage = mergeAccount(failed)
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
            scheduleNextWeeklyAutoKickCheck(for: account.id, usage: newUsage, now: Date())
            syncWeeklyObservation(for: account.id, usage: newUsage)

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
                    staleAfter: staleSessionThreshold,
                    refreshBeforeExpiry: tokenRefreshExpiryBuffer
                )
                let merged = mergeAccount(result.account)
                accountStatuses[account.id] = status(for: merged)
            } catch let error as CodexAPIService.APIError {
                let failedError: CodexAPIService.APIError = if error == .unauthorized {
                    .networkError("Refresh token rejected")
                } else {
                    error
                }
                let failed = CodexAPIService.markRefreshFailure(for: current, error: failedError)
                let merged = mergeAccount(failed)
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
            Task { await evaluateWeeklyAutoKickCandidates(now: now) }
            return
        }

        markStaleAccounts(now: now)
        Task {
            await auditAllSessions(trigger: trigger)
            await evaluateWeeklyAutoKickCandidates(now: now)
        }
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

    private func startWeeklyAutoKickTimer() {
        weeklyAutoKickTimer?.invalidate()
        weeklyAutoKickTimer = Timer.scheduledTimer(withTimeInterval: weeklyAutoKickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.evaluateWeeklyAutoKickCandidates()
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
        pendingReauthAccountID = nil
        beginAddAccountFlow()
    }

    private func beginAddAccountFlow() {
        guard ensureImportCodexHomeExists() else {
            addAccountStatus = .error("Could not prepare import auth folder.")
            showingAddAccount = true
            return
        }

        showingAddAccount = true
        addAccountStatus = .watching

        addAccountWatcher.codexHomeOverride = importCodexHome
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
        pendingReauthAccountID = nil
        addAccountWatcher.codexHomeOverride = nil
        addAccountWatcher.stop()
    }

    private func handleAddAccountAuthFileChange() {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard let account = CodexAPIService.readAuthFile(codexHome: importCodexHome) else {
                addAccountStatus = .error("Could not read auth file. Try again.")
                return
            }

            if let pendingReauthAccountID,
               pendingReauthAccountID != account.id,
               let expected = currentAccount(id: pendingReauthAccountID)
            {
                addAccountStatus = .error("Signed into \(account.email). Expected \(expected.email).")
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
            addAccountWatcher.codexHomeOverride = nil
            pendingReauthAccountID = nil
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
        weeklyAutoKickNextCheckAt.removeValue(forKey: account.id)
        normalizePinnedOrder()
        persistAccounts()
    }

    func reauthAccount(_ account: CodexAccount) {
        pendingReauthAccountID = account.id
        beginAddAccountFlow()
    }

    @discardableResult
    private func ensureImportCodexHomeExists() -> Bool {
        do {
            try FileManager.default.createDirectory(
                atPath: importCodexHome,
                withIntermediateDirectories: true
            )
            return true
        } catch {
            print("AccountsViewModel: Failed to create import CODEX_HOME: \(error)")
            return false
        }
    }

    // MARK: - Pinning

    func togglePin(_ account: CodexAccount) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx].isPinned.toggle()
        if accounts[idx].isPinned {
            accounts[idx].pinnedOrder = nextPinnedOrder()
        } else {
            accounts[idx].pinnedOrder = nil
        }
        normalizePinnedOrder()
        rebuildWeeklyAutoKickSchedule()
        persistAccounts()
    }

    func movePinnedAccount(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID else { return }
        let pinned = accounts
            .filter(\.isPinned)
            .sorted { a, b in
                let ao = a.pinnedOrder ?? Int.max
                let bo = b.pinnedOrder ?? Int.max
                if ao != bo { return ao < bo }
                return a.addedAt < b.addedAt
            }
        guard let fromIndex = pinned.firstIndex(where: { $0.id == draggedID }),
              let toIndex = pinned.firstIndex(where: { $0.id == targetID })
        else {
            return
        }

        var reordered = pinned
        let dragged = reordered.remove(at: fromIndex)
        let adjustedIndex = fromIndex < toIndex ? max(0, toIndex - 1) : toIndex
        reordered.insert(dragged, at: adjustedIndex)

        for (order, pinnedAccount) in reordered.enumerated() {
            if let idx = accounts.firstIndex(where: { $0.id == pinnedAccount.id }) {
                accounts[idx].pinnedOrder = order
            }
        }

        normalizePinnedOrder()
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

    // MARK: - Weekly Auto Kick

    func setWeeklyAutoKickOverride(_ overrideValue: WeeklyAutoKickOverride, for account: CodexAccount) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx].weeklyAutoKickOverride = overrideValue
        rebuildWeeklyAutoKickSchedule()
        persistAccounts()
    }

    func weeklyAutoKickOverride(for account: CodexAccount) -> WeeklyAutoKickOverride {
        currentAccount(id: account.id)?.weeklyAutoKickOverride ?? account.weeklyAutoKickOverride
    }

    func isWeeklyAutoKickEnabled(for account: CodexAccount) -> Bool {
        let current = currentAccount(id: account.id) ?? account
        switch current.weeklyAutoKickOverride {
        case .forceOn:
            return true
        case .forceOff:
            return false
        case .inherit:
            switch weeklyAutoKickMode {
            case .off:
                return false
            case .pinnedAccounts:
                return current.isPinned
            case .allAccounts:
                return true
            }
        }
    }

    func weeklyAutoKickIndicator(for account: CodexAccount, usage: AccountUsage?) -> WeeklyAutoKickIndicator? {
        let current = currentAccount(id: account.id) ?? account
        let now = Date()

        if let usage,
           let freshResetStatus = freshWeeklyResetIndicator(for: current, usage: usage, now: now)
        {
            return freshResetStatus
        }

        if !isWeeklyAutoKickEnabled(for: current) {
            if let failure = current.lastWeeklyAutoKickFailure,
               current.weeklyAutoKickAttemptCount >= weeklyAutoKickMaxAttempts
            {
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.trianglebadge.exclamationmark.fill",
                    color: .orange,
                    help: "Weekly auto-kick failed this cycle: \(failure)"
                )
            }
            return nil
        }

        if current.authState == .needsReauth {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.slash.fill",
                color: .red,
                help: "Weekly auto-kick unavailable until re-authenticated"
            )
        }

        if current.authState == .degraded {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.slash.fill",
                color: .orange,
                help: "Weekly auto-kick paused while refresh is failing"
            )
        }

        if let usage {
            if current.weeklyAutoKickAttemptCount > 0 {
                if current.weeklyAutoKickAttemptCount >= weeklyAutoKickMaxAttempts {
                    if let failure = current.lastWeeklyAutoKickFailure {
                        return WeeklyAutoKickIndicator(
                            symbol: "bolt.trianglebadge.exclamationmark.fill",
                            color: .orange,
                            help: "Weekly auto-kick failed this cycle: \(failure)"
                        )
                    }
                    return WeeklyAutoKickIndicator(
                        symbol: "bolt.trianglebadge.exclamationmark.fill",
                        color: .orange,
                        help: "Weekly auto-kick failed this cycle"
                    )
                }

                let retryDate = current.lastWeeklyAutoKickAttemptAt?.addingTimeInterval(weeklyAutoKickRetryDelay)
                let retrySuffix = retryDate.map { ", retry \($0.resetDescription)" } ?? ""
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.circle.fill",
                    color: .cyan,
                    help: "Weekly auto-kick attempt \(current.weeklyAutoKickAttemptCount)/\(weeklyAutoKickMaxAttempts)\(retrySuffix)"
                )
            }

            if usage.weeklyResetIsOverdue(now: now, grace: weeklyAutoKickDelay) {
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.circle.fill",
                    color: .cyan,
                    help: "Weekly auto-kick is actively watching this overdue weekly reset"
                )
            }

            if let weeklyResetAt = usage.weeklyResetAt {
                let secondsUntilReset = weeklyResetAt.timeIntervalSince(now)
                if secondsUntilReset <= weeklyAutoKickSoonThreshold {
                    return WeeklyAutoKickIndicator(
                        symbol: "bolt.circle",
                        color: .cyan.opacity(0.95),
                        help: "Weekly auto-kick is watching closely before reset"
                    )
                }
                if secondsUntilReset <= weeklyAutoKickNearResetThreshold {
                    return WeeklyAutoKickIndicator(
                        symbol: "bolt.circle",
                        color: .blue.opacity(0.95),
                        help: "Weekly auto-kick is armed for this account and will ramp up closer to reset"
                    )
                }
            }
        }

        if let successAt = current.lastWeeklyAutoKickSuccessAt,
           let usage,
           usage.weeklyCycleIdentifier == current.lastWeeklyAutoKickCycleID
        {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.badge.checkmark",
                color: .green,
                help: "Weekly auto-kick activated \(successAt.relativeDescription)"
            )
        }

        switch current.weeklyAutoKickOverride {
        case .forceOn:
            return WeeklyAutoKickIndicator(
                symbol: "bolt.badge.checkmark",
                color: .green.opacity(0.95),
                help: "Weekly auto-kick is enabled for this account"
            )
        case .forceOff:
            return nil
        case .inherit:
            switch weeklyAutoKickMode {
            case .off:
                return nil
            case .pinnedAccounts:
                return current.isPinned
                    ? WeeklyAutoKickIndicator(
                        symbol: "bolt.badge.checkmark",
                        color: .green.opacity(0.95),
                        help: "Weekly auto-kick follows the pinned-accounts setting"
                    )
                    : nil
            case .allAccounts:
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.badge.checkmark",
                    color: .green.opacity(0.95),
                    help: "Weekly auto-kick follows the global setting"
                )
            }
        }
    }

    private func freshWeeklyResetIndicator(
        for account: CodexAccount,
        usage: AccountUsage,
        now: Date
    ) -> WeeklyAutoKickIndicator? {
        guard isFreshWeeklyResetWindow(usage: usage, now: now),
              let cycleID = usage.weeklyCycleIdentifier
        else {
            return nil
        }

        if !isWeeklyAutoKickEnabled(for: account) {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.slash",
                color: .secondary.opacity(0.8),
                help: "Fresh weekly reset detected, but weekly auto-kick is off for this account."
            )
        }

        if account.authState == .needsReauth {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.slash.fill",
                color: .red,
                help: "Fresh weekly reset detected, but weekly auto-kick needs re-authentication first."
            )
        }

        if account.authState == .degraded {
            return WeeklyAutoKickIndicator(
                symbol: "bolt.slash.fill",
                color: .orange,
                help: "Fresh weekly reset detected, but weekly auto-kick is paused while refresh is failing."
            )
        }

        if account.lastWeeklyAutoKickCycleID == cycleID {
            if let failure = account.lastWeeklyAutoKickFailure {
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.trianglebadge.exclamationmark.fill",
                    color: .orange,
                    help: "Weekly auto-kick tried this fresh reset but failed: \(failure)"
                )
            }

            if account.weeklyAutoKickAttemptCount > 0 {
                let retryDate = account.lastWeeklyAutoKickAttemptAt?.addingTimeInterval(weeklyAutoKickRetryDelay)
                let retrySuffix = retryDate.map { ", retry \($0.resetDescription)" } ?? ""
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.circle.fill",
                    color: .cyan,
                    help: "Weekly auto-kick is activating this fresh reset, attempt \(account.weeklyAutoKickAttemptCount)/\(weeklyAutoKickMaxAttempts)\(retrySuffix)."
                )
            }

            if let successAt = account.lastWeeklyAutoKickSuccessAt {
                return WeeklyAutoKickIndicator(
                    symbol: "bolt.badge.checkmark",
                    color: .green,
                    help: "Weekly auto-kick sent the activation message for this reset \(successAt.relativeDescription). If usage still shows 100%, the message was accepted but Codex has not reported token usage yet."
                )
            }

            return WeeklyAutoKickIndicator(
                symbol: "bolt.circle",
                color: .green.opacity(0.95),
                help: "Weekly auto-kick already handled this fresh reset cycle."
            )
        }

        return WeeklyAutoKickIndicator(
            symbol: "bolt.circle.fill",
            color: .cyan,
            help: "Fresh weekly reset detected. Activation pending."
        )
    }

    func evaluateWeeklyAutoKickCandidates(now: Date = Date()) async {
        guard !isEvaluatingWeeklyAutoKick else { return }
        guard !accounts.isEmpty else { return }

        isEvaluatingWeeklyAutoKick = true
        defer { isEvaluatingWeeklyAutoKick = false }

        for account in accounts {
            if let nextCheckAt = weeklyAutoKickNextCheckAt[account.id],
               nextCheckAt > now
            {
                continue
            }
            await evaluateWeeklyAutoKick(for: account.id, now: now)
        }
    }

    private func evaluateWeeklyAutoKick(for accountID: String, now: Date) async {
        guard let account = currentAccount(id: accountID) else { return }
        guard isWeeklyAutoKickEnabled(for: account) else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }
        guard account.authState != .needsReauth, account.authState != .degraded else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }
        guard let usage = usageData[accountID], usage.hasWeeklyWindow else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        if shouldActivateFreshWeeklyReset(account: account, usage: usage, now: now) {
            let cycleID = usage.weeklyCycleIdentifier
            if shouldPauseWeeklyAutoKick(account: account, cycleID: cycleID, now: now) {
                scheduleRetryWeeklyAutoKickCheck(for: accountID, account: account, now: now)
                return
            }

            await runWeeklyAutoKickAttempt(for: account, cycleID: cycleID, now: now)
            return
        }

        if !usage.weeklyResetIsOverdue(now: now, grace: weeklyAutoKickDelay) {
            scheduleNextWeeklyAutoKickCheck(for: accountID, usage: usage, now: now)
            return
        }

        let cycleID = usage.weeklyCycleIdentifier
        if shouldPauseWeeklyAutoKick(account: account, cycleID: cycleID, now: now) {
            scheduleRetryWeeklyAutoKickCheck(for: accountID, account: account, now: now)
            return
        }

        await refreshAccount(account, trigger: .timer)

        guard let refreshedAccount = currentAccount(id: accountID),
              let refreshedUsage = usageData[accountID],
              refreshedUsage.hasWeeklyWindow
        else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        if !refreshedUsage.weeklyResetIsOverdue(now: now, grace: weeklyResetDisplayGrace) {
            scheduleNextWeeklyAutoKickCheck(for: accountID, usage: refreshedUsage, now: now)
            return
        }

        let refreshedCycleID = refreshedUsage.weeklyCycleIdentifier
        if shouldPauseWeeklyAutoKick(account: refreshedAccount, cycleID: refreshedCycleID, now: now) {
            scheduleRetryWeeklyAutoKickCheck(for: accountID, account: refreshedAccount, now: now)
            return
        }

        await runWeeklyAutoKickAttempt(for: refreshedAccount, cycleID: refreshedCycleID, now: now)
    }

    private func shouldPauseWeeklyAutoKick(account: CodexAccount, cycleID: String?, now: Date) -> Bool {
        if let cycleID,
           account.lastWeeklyAutoKickCycleID == cycleID
        {
            if account.weeklyAutoKickAttemptCount >= weeklyAutoKickMaxAttempts {
                return true
            }
            if let lastAttemptAt = account.lastWeeklyAutoKickAttemptAt,
               now.timeIntervalSince(lastAttemptAt) < weeklyAutoKickRetryDelay
            {
                return true
            }
        }

        return false
    }

    private func shouldActivateFreshWeeklyReset(
        account: CodexAccount,
        usage: AccountUsage,
        now: Date
    ) -> Bool {
        guard isWeeklyAutoKickEnabled(for: account) else { return false }
        guard account.authState != .needsReauth, account.authState != .degraded else { return false }
        guard let weeklyResetAt = usage.weeklyResetAt,
              let cycleID = usage.weeklyCycleIdentifier
        else {
            return false
        }
        guard weeklyResetAt > now else { return false }
        guard account.lastWeeklyAutoKickCycleID != cycleID else { return false }

        if let weeklyRemaining = usage.weeklyRemainingPercent {
            return weeklyRemaining >= 99.5
        }

        return usage.isWeeklyPrimary && usage.remainingPercent >= 99.5
    }

    private func isFreshWeeklyResetWindow(usage: AccountUsage, now: Date) -> Bool {
        guard let weeklyResetAt = usage.weeklyResetAt,
              usage.weeklyCycleIdentifier != nil,
              weeklyResetAt > now
        else {
            return false
        }

        if let weeklyRemaining = usage.weeklyRemainingPercent {
            return weeklyRemaining >= 99.5
        }

        return usage.isWeeklyPrimary && usage.remainingPercent >= 99.5
    }

    private func runWeeklyAutoKickAttempt(for account: CodexAccount, cycleID: String?, now: Date) async {
        guard let attemptAccount = markWeeklyAutoKickAttempt(for: account.id, cycleID: cycleID, now: now) else { return }

        let result = await TestMessageService.send(account: attemptAccount)
        if !result.success {
            recordWeeklyAutoKickFailure(for: account.id, message: result.message)
            if let updatedAccount = currentAccount(id: account.id) {
                scheduleRetryWeeklyAutoKickCheck(for: account.id, account: updatedAccount, now: now)
            }
            return
        }

        try? await Task.sleep(for: .seconds(weeklyAutoKickActivationDelay))
        await refreshAccount(attemptAccount, trigger: .timer)

        guard let updatedUsage = usageData[account.id], updatedUsage.hasWeeklyWindow else {
            recordWeeklyAutoKickFailure(for: account.id, message: "Usage did not refresh after auto-kick")
            if let updatedAccount = currentAccount(id: account.id) {
                scheduleRetryWeeklyAutoKickCheck(for: account.id, account: updatedAccount, now: now)
            }
            return
        }

        if updatedUsage.weeklyResetIsOverdue(grace: weeklyResetDisplayGrace) {
            recordWeeklyAutoKickFailure(for: account.id, message: "Weekly window still looks stale")
            if let updatedAccount = currentAccount(id: account.id) {
                scheduleRetryWeeklyAutoKickCheck(for: account.id, account: updatedAccount, now: now)
            }
            return
        }

        recordWeeklyAutoKickSuccess(for: account.id, at: Date())
        scheduleNextWeeklyAutoKickCheck(for: account.id, usage: updatedUsage, now: Date())
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
        if !normalized.isPinned {
            normalized.pinnedOrder = nil
        }
        normalized = CodexAPIService.markStaleIfNeeded(
            for: normalized,
            staleAfter: staleSessionThreshold
        )
        return normalized
    }

    private func syncWeeklyObservation(for accountID: String, usage: AccountUsage) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }

        let observedResetAt = usage.weeklyResetAt
        let previousObservedResetAt = accounts[idx].lastObservedWeeklyResetAt
        guard observedResetAt != previousObservedResetAt else { return }

        accounts[idx].lastObservedWeeklyResetAt = observedResetAt
        accounts[idx].lastWeeklyAutoKickFailure = nil
        accounts[idx].weeklyAutoKickAttemptCount = 0
        if observedResetAt != nil {
            accounts[idx].lastWeeklyAutoKickAttemptAt = nil
        }
        scheduleNextWeeklyAutoKickCheck(for: accountID, usage: usage, now: Date())
        persistAccounts()
    }

    @discardableResult
    private func markWeeklyAutoKickAttempt(for accountID: String, cycleID: String?, now: Date) -> CodexAccount? {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return nil }

        if accounts[idx].lastWeeklyAutoKickCycleID != cycleID {
            accounts[idx].weeklyAutoKickAttemptCount = 0
            accounts[idx].lastWeeklyAutoKickFailure = nil
        }

        accounts[idx].lastWeeklyAutoKickCycleID = cycleID
        accounts[idx].lastWeeklyAutoKickAttemptAt = now
        accounts[idx].weeklyAutoKickAttemptCount += 1
        persistAccounts()
        return accounts[idx]
    }

    private func recordWeeklyAutoKickFailure(for accountID: String, message: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[idx].lastWeeklyAutoKickFailure = message
        persistAccounts()
    }

    private func recordWeeklyAutoKickSuccess(for accountID: String, at date: Date) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[idx].lastWeeklyAutoKickSuccessAt = date
        accounts[idx].lastWeeklyAutoKickFailure = nil
        accounts[idx].weeklyAutoKickAttemptCount = 0
        accounts[idx].lastWeeklyAutoKickAttemptAt = nil
        persistAccounts()
    }

    private func scheduleNextWeeklyAutoKickCheck(for accountID: String, usage: AccountUsage, now: Date) {
        guard let account = currentAccount(id: accountID) else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        guard isWeeklyAutoKickEnabled(for: account) else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        guard let weeklyResetAt = usage.weeklyResetAt else {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        let secondsUntilReset = weeklyResetAt.timeIntervalSince(now)
        let nextCheckAt: Date

        if shouldActivateFreshWeeklyReset(account: account, usage: usage, now: now) {
            nextCheckAt = now
        } else if secondsUntilReset <= -weeklyAutoKickDelay {
            nextCheckAt = now.addingTimeInterval(weeklyAutoKickInterval)
        } else if secondsUntilReset <= 0 {
            nextCheckAt = weeklyResetAt.addingTimeInterval(weeklyAutoKickDelay)
        } else if secondsUntilReset <= weeklyAutoKickSoonThreshold {
            nextCheckAt = now.addingTimeInterval(weeklyAutoKickSoonInterval)
        } else if secondsUntilReset <= weeklyAutoKickNearResetThreshold {
            nextCheckAt = now.addingTimeInterval(weeklyAutoKickNearResetInterval)
        } else {
            nextCheckAt = now.addingTimeInterval(weeklyAutoKickFarInterval)
        }

        weeklyAutoKickNextCheckAt[accountID] = nextCheckAt
    }

    private func scheduleRetryWeeklyAutoKickCheck(for accountID: String, account: CodexAccount, now: Date) {
        if account.weeklyAutoKickAttemptCount >= weeklyAutoKickMaxAttempts {
            weeklyAutoKickNextCheckAt.removeValue(forKey: accountID)
            return
        }

        if let lastAttemptAt = account.lastWeeklyAutoKickAttemptAt {
            weeklyAutoKickNextCheckAt[accountID] = lastAttemptAt.addingTimeInterval(weeklyAutoKickRetryDelay)
        } else {
            weeklyAutoKickNextCheckAt[accountID] = now.addingTimeInterval(weeklyAutoKickRetryDelay)
        }
    }

    private func rebuildWeeklyAutoKickSchedule(now: Date = Date()) {
        for account in accounts {
            guard let usage = usageData[account.id], usage.hasWeeklyWindow else {
                weeklyAutoKickNextCheckAt.removeValue(forKey: account.id)
                continue
            }
            scheduleNextWeeklyAutoKickCheck(for: account.id, usage: usage, now: now)
        }
    }

    private func persistAccounts() {
        AccountStore.save(accounts)
    }

    private func normalizePinnedOrder() {
        let pinnedIDs = accounts
            .filter(\.isPinned)
            .sorted { a, b in
                let ao = a.pinnedOrder ?? Int.max
                let bo = b.pinnedOrder ?? Int.max
                if ao != bo { return ao < bo }
                return a.addedAt < b.addedAt
            }
            .map(\.id)

        for (order, id) in pinnedIDs.enumerated() {
            if let idx = accounts.firstIndex(where: { $0.id == id }) {
                accounts[idx].pinnedOrder = order
            }
        }

        for idx in accounts.indices where !accounts[idx].isPinned {
            accounts[idx].pinnedOrder = nil
        }
    }

    private func nextPinnedOrder() -> Int {
        accounts.compactMap(\.pinnedOrder).max().map { $0 + 1 } ?? 0
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
            isPinned: existing.isPinned,
            pinnedOrder: existing.pinnedOrder,
            weeklyAutoKickOverride: existing.weeklyAutoKickOverride,
            lastObservedWeeklyResetAt: existing.lastObservedWeeklyResetAt,
            lastWeeklyAutoKickCycleID: existing.lastWeeklyAutoKickCycleID,
            lastWeeklyAutoKickAttemptAt: existing.lastWeeklyAutoKickAttemptAt,
            lastWeeklyAutoKickSuccessAt: existing.lastWeeklyAutoKickSuccessAt,
            lastWeeklyAutoKickFailure: existing.lastWeeklyAutoKickFailure,
            weeklyAutoKickAttemptCount: existing.weeklyAutoKickAttemptCount
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
