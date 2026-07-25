//
//  CodexAccount.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

enum AuthState: String, Codable, Hashable {
    case healthy
    case stale
    case degraded
    case needsReauth

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .stale: return "Stale"
        case .degraded: return "Needs attention"
        case .needsReauth: return "Expired"
        }
    }
}

enum WeeklyAutoKickMode: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case pinnedAccounts = "Pinned Accounts"
    case allAccounts = "All Accounts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .off: return "power"
        case .pinnedAccounts: return "pin"
        case .allAccounts: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .off: return "Never send an automatic weekly kick message"
        case .pinnedAccounts: return "Only pinned accounts can auto-start a new weekly window"
        case .allAccounts: return "Any healthy tracked account can auto-start a new weekly window"
        }
    }
}

enum WeeklyAutoKickOverride: String, Codable, CaseIterable, Identifiable {
    case inherit = "Inherit Global Setting"
    case forceOn = "Always On"
    case forceOff = "Always Off"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inherit: return "point.3.connected.trianglepath.dotted"
        case .forceOn: return "bolt.badge.checkmark"
        case .forceOff: return "bolt.slash"
        }
    }
}

struct CodexAccount: Identifiable, Codable, Hashable {
    let id: String
    var email: String
    var planType: String
    var accessToken: String
    var refreshToken: String
    var idToken: String?
    var accountId: String?
    var codexHomePath: String?
    var codexAuthJSON: String?
    var lastTokenRefresh: Date?
    var lastSuccessfulUsageAt: Date?
    var lastSuccessfulTokenRefreshAt: Date?
    var lastRefreshAttemptAt: Date?
    var lastRefreshFailureAt: Date?
    var consecutiveRefreshFailures: Int
    var authState: AuthState
    let addedAt: Date
    var isPinned: Bool
    var pinnedOrder: Int?
    var weeklyAutoKickOverride: WeeklyAutoKickOverride
    var lastObservedWeeklyResetAt: Date?
    var lastWeeklyAutoKickCycleID: String?
    var lastWeeklyAutoKickAttemptAt: Date?
    var lastWeeklyAutoKickSuccessAt: Date?
    var lastWeeklyAutoKickFailure: String?
    var weeklyAutoKickAttemptCount: Int

    enum CodingKeys: String, CodingKey {
        case id, email, planType, accessToken, refreshToken
        case idToken, accountId, codexHomePath, codexAuthJSON, lastTokenRefresh
        case lastSuccessfulUsageAt, lastSuccessfulTokenRefreshAt
        case lastRefreshAttemptAt, lastRefreshFailureAt
        case consecutiveRefreshFailures, authState
        case addedAt, isPinned, pinnedOrder
        case weeklyAutoKickOverride, lastObservedWeeklyResetAt
        case lastWeeklyAutoKickCycleID, lastWeeklyAutoKickAttemptAt
        case lastWeeklyAutoKickSuccessAt, lastWeeklyAutoKickFailure
        case weeklyAutoKickAttemptCount
    }

    init(
        email: String,
        planType: String,
        accessToken: String,
        refreshToken: String,
        idToken: String? = nil,
        accountId: String? = nil,
        codexHomePath: String? = nil,
        codexAuthJSON: String? = nil,
        lastTokenRefresh: Date? = nil,
        lastSuccessfulUsageAt: Date? = nil,
        lastSuccessfulTokenRefreshAt: Date? = nil,
        lastRefreshAttemptAt: Date? = nil,
        lastRefreshFailureAt: Date? = nil,
        consecutiveRefreshFailures: Int = 0,
        authState: AuthState = .healthy,
        addedAt: Date = Date(),
        isPinned: Bool = false,
        pinnedOrder: Int? = nil,
        weeklyAutoKickOverride: WeeklyAutoKickOverride = .inherit,
        lastObservedWeeklyResetAt: Date? = nil,
        lastWeeklyAutoKickCycleID: String? = nil,
        lastWeeklyAutoKickAttemptAt: Date? = nil,
        lastWeeklyAutoKickSuccessAt: Date? = nil,
        lastWeeklyAutoKickFailure: String? = nil,
        weeklyAutoKickAttemptCount: Int = 0
    ) {
        self.id = email.lowercased()
        self.email = email
        self.planType = planType
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountId = accountId
        self.codexHomePath = codexHomePath
        self.codexAuthJSON = codexAuthJSON
        self.lastTokenRefresh = lastTokenRefresh
        self.lastSuccessfulUsageAt = lastSuccessfulUsageAt
        self.lastSuccessfulTokenRefreshAt = lastSuccessfulTokenRefreshAt ?? lastTokenRefresh
        self.lastRefreshAttemptAt = lastRefreshAttemptAt
        self.lastRefreshFailureAt = lastRefreshFailureAt
        self.consecutiveRefreshFailures = consecutiveRefreshFailures
        self.authState = authState
        self.addedAt = addedAt
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
        self.weeklyAutoKickOverride = weeklyAutoKickOverride
        self.lastObservedWeeklyResetAt = lastObservedWeeklyResetAt
        self.lastWeeklyAutoKickCycleID = lastWeeklyAutoKickCycleID
        self.lastWeeklyAutoKickAttemptAt = lastWeeklyAutoKickAttemptAt
        self.lastWeeklyAutoKickSuccessAt = lastWeeklyAutoKickSuccessAt
        self.lastWeeklyAutoKickFailure = lastWeeklyAutoKickFailure
        self.weeklyAutoKickAttemptCount = weeklyAutoKickAttemptCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        planType = try c.decode(String.self, forKey: .planType)
        accessToken = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        idToken = try c.decodeIfPresent(String.self, forKey: .idToken)
        accountId = try c.decodeIfPresent(String.self, forKey: .accountId)
        codexHomePath = try c.decodeIfPresent(String.self, forKey: .codexHomePath)
        codexAuthJSON = try c.decodeIfPresent(String.self, forKey: .codexAuthJSON)
        lastTokenRefresh = try c.decodeIfPresent(Date.self, forKey: .lastTokenRefresh)
        lastSuccessfulUsageAt = try c.decodeIfPresent(Date.self, forKey: .lastSuccessfulUsageAt)
        lastSuccessfulTokenRefreshAt = try c.decodeIfPresent(Date.self, forKey: .lastSuccessfulTokenRefreshAt) ?? lastTokenRefresh
        lastRefreshAttemptAt = try c.decodeIfPresent(Date.self, forKey: .lastRefreshAttemptAt)
        lastRefreshFailureAt = try c.decodeIfPresent(Date.self, forKey: .lastRefreshFailureAt)
        consecutiveRefreshFailures = (try? c.decode(Int.self, forKey: .consecutiveRefreshFailures)) ?? 0
        authState = (try? c.decode(AuthState.self, forKey: .authState)) ?? .healthy
        addedAt = try c.decode(Date.self, forKey: .addedAt)
        isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        pinnedOrder = try c.decodeIfPresent(Int.self, forKey: .pinnedOrder)
        weeklyAutoKickOverride = (try? c.decode(WeeklyAutoKickOverride.self, forKey: .weeklyAutoKickOverride)) ?? .inherit
        lastObservedWeeklyResetAt = try c.decodeIfPresent(Date.self, forKey: .lastObservedWeeklyResetAt)
        lastWeeklyAutoKickCycleID = try c.decodeIfPresent(String.self, forKey: .lastWeeklyAutoKickCycleID)
        lastWeeklyAutoKickAttemptAt = try c.decodeIfPresent(Date.self, forKey: .lastWeeklyAutoKickAttemptAt)
        lastWeeklyAutoKickSuccessAt = try c.decodeIfPresent(Date.self, forKey: .lastWeeklyAutoKickSuccessAt)
        lastWeeklyAutoKickFailure = try c.decodeIfPresent(String.self, forKey: .lastWeeklyAutoKickFailure)
        weeklyAutoKickAttemptCount = (try? c.decode(Int.self, forKey: .weeklyAutoKickAttemptCount)) ?? 0
    }

    /// First 8 chars of account UUID for display
    var shortAccountId: String? {
        guard let accountId, !accountId.isEmpty else { return nil }
        return String(accountId.prefix(8))
    }

    var planDisplayName: String {
        switch planType.lowercased() {
        case "pro": return "Pro"
        case "plus": return "Plus"
        case "go": return "Go"
        case "free": return "Free"
        case "team": return "Team"
        case "enterprise": return "Enterprise"
        case "edu", "education": return "Edu"
        default: return planType.capitalized
        }
    }

    var lastAuthValidationAt: Date? {
        [lastSuccessfulTokenRefreshAt, lastSuccessfulUsageAt, lastTokenRefresh, addedAt].compactMap { $0 }.max()
    }
}

enum UsageWindowKind: String, Codable, CaseIterable {
    case shortTerm = "Short-term"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"

    static func classify(seconds: Int) -> UsageWindowKind {
        if seconds <= 3 * 24 * 3600 {
            return .shortTerm
        } else if seconds >= 5 * 24 * 3600 && seconds <= 8 * 24 * 3600 {
            return .weekly
        } else if seconds >= 25 * 24 * 3600 && seconds <= 35 * 24 * 3600 {
            return .monthly
        } else {
            return .custom
        }
    }

    var displayLabel: String {
        switch self {
        case .shortTerm: return "Short-term"
        case .weekly: return "Weekly"
        case .monthly: return "30-day"
        case .custom: return "Custom"
        }
    }
}

struct UsageWindow: Equatable {
    var usedPercent: Double
    var resetAt: Date?
    var resetAfterSeconds: Int?
    var windowDurationSeconds: Int
    var kind: UsageWindowKind
    var allowed: Bool?
    var limitReached: Bool?

    init(
        usedPercent: Double,
        resetAt: Date?,
        resetAfterSeconds: Int? = nil,
        windowDurationSeconds: Int,
        kind: UsageWindowKind? = nil,
        allowed: Bool? = nil,
        limitReached: Bool? = nil
    ) {
        self.usedPercent = usedPercent
        self.resetAt = resetAt
        self.resetAfterSeconds = resetAfterSeconds
        self.windowDurationSeconds = windowDurationSeconds
        self.kind = kind ?? UsageWindowKind.classify(seconds: windowDurationSeconds)
        self.allowed = allowed
        self.limitReached = limitReached
    }

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }

    var isLimitReached: Bool {
        if allowed == false { return true }
        if limitReached == true { return true }
        return false
    }

    var displayLabel: String {
        switch kind {
        case .shortTerm:
            if windowDurationSeconds == 18000 {
                return "5-hour"
            } else if windowDurationSeconds > 0 && windowDurationSeconds % 3600 == 0 {
                let hours = windowDurationSeconds / 3600
                if hours < 24 {
                    return "\(hours)-hour"
                } else {
                    let days = hours / 24
                    return "\(days)-day"
                }
            } else {
                return "Short-term"
            }
        case .weekly:
            return "Weekly"
        case .monthly:
            return "30-day"
        case .custom:
            let days = windowDurationSeconds / 86400
            if days >= 1 {
                return "\(days)-day"
            } else {
                let hours = windowDurationSeconds / 3600
                return "\(hours)-hour"
            }
        }
    }
}

struct AccountUsage: Equatable {
    static let weeklyWindowThresholdSeconds = 5 * 24 * 60 * 60
    static let monthlyWindowThresholdSeconds = 25 * 24 * 60 * 60

    var primaryWindow: UsageWindow?
    var secondaryWindow: UsageWindow?
    var additionalWindows: [UsageWindow]

    var allowed: Bool?
    var limitReached: Bool?
    var rateLimitReachedType: String?
    var creditsBalance: Double?
    var hasCredits: Bool
    var isUnlimited: Bool
    var lastUpdated: Date
    var error: String?
    var lastActivityAt: Date?

    init(
        primaryWindow: UsageWindow? = nil,
        secondaryWindow: UsageWindow? = nil,
        additionalWindows: [UsageWindow] = [],
        allowed: Bool? = nil,
        limitReached: Bool? = nil,
        rateLimitReachedType: String? = nil,
        creditsBalance: Double? = nil,
        hasCredits: Bool = false,
        isUnlimited: Bool = false,
        lastUpdated: Date = Date(),
        error: String? = nil,
        lastActivityAt: Date? = nil
    ) {
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.additionalWindows = additionalWindows
        self.allowed = allowed
        self.limitReached = limitReached
        self.rateLimitReachedType = rateLimitReachedType
        self.creditsBalance = creditsBalance
        self.hasCredits = hasCredits
        self.isUnlimited = isUnlimited
        self.lastUpdated = lastUpdated
        self.error = error
        self.lastActivityAt = lastActivityAt
    }

    init(
        usedPercent: Double,
        resetAt: Date?,
        primaryWindowSeconds: Int?,
        weeklyUsedPercent: Double?,
        weeklyResetAt: Date?,
        weeklyWindowSeconds: Int?,
        creditsBalance: Double?,
        hasCredits: Bool,
        isUnlimited: Bool,
        lastUpdated: Date,
        error: String?,
        lastActivityAt: Date? = nil,
        allowed: Bool? = nil,
        limitReached: Bool? = nil,
        rateLimitReachedType: String? = nil
    ) {
        var primWindow: UsageWindow? = nil
        if let sec = primaryWindowSeconds {
            primWindow = UsageWindow(
                usedPercent: usedPercent,
                resetAt: resetAt,
                windowDurationSeconds: sec,
                kind: UsageWindowKind.classify(seconds: sec),
                allowed: allowed,
                limitReached: limitReached
            )
        } else {
            primWindow = UsageWindow(
                usedPercent: usedPercent,
                resetAt: resetAt,
                windowDurationSeconds: 0,
                kind: .shortTerm,
                allowed: allowed,
                limitReached: limitReached
            )
        }

        var secWindow: UsageWindow? = nil
        if let wUsed = weeklyUsedPercent, let wSec = weeklyWindowSeconds {
            secWindow = UsageWindow(
                usedPercent: wUsed,
                resetAt: weeklyResetAt,
                windowDurationSeconds: wSec,
                kind: UsageWindowKind.classify(seconds: wSec),
                allowed: allowed,
                limitReached: limitReached
            )
        }

        if let prim = primWindow, let sec = secWindow, prim.windowDurationSeconds == sec.windowDurationSeconds {
            self.primaryWindow = prim
            self.secondaryWindow = nil
        } else {
            self.primaryWindow = primWindow
            self.secondaryWindow = secWindow
        }

        self.additionalWindows = []
        self.allowed = allowed
        self.limitReached = limitReached
        self.rateLimitReachedType = rateLimitReachedType
        self.creditsBalance = creditsBalance
        self.hasCredits = hasCredits
        self.isUnlimited = isUnlimited
        self.lastUpdated = lastUpdated
        self.error = error
        self.lastActivityAt = lastActivityAt
    }

    var usedPercent: Double {
        get { primaryWindow?.usedPercent ?? 0 }
        set {
            if primaryWindow != nil {
                primaryWindow?.usedPercent = newValue
            } else {
                primaryWindow = UsageWindow(usedPercent: newValue, resetAt: nil, windowDurationSeconds: 0)
            }
        }
    }

    var resetAt: Date? {
        get { primaryWindow?.resetAt }
        set { primaryWindow?.resetAt = newValue }
    }

    var primaryWindowSeconds: Int? {
        get { primaryWindow?.windowDurationSeconds }
        set {
            if let newValue {
                if primaryWindow != nil {
                    primaryWindow?.windowDurationSeconds = newValue
                    primaryWindow?.kind = UsageWindowKind.classify(seconds: newValue)
                } else {
                    primaryWindow = UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: newValue)
                }
            }
        }
    }

    var weeklyWindow: UsageWindow? {
        if primaryWindow?.kind == .weekly {
            return primaryWindow
        }
        if secondaryWindow?.kind == .weekly {
            return secondaryWindow
        }
        return additionalWindows.first(where: { $0.kind == .weekly })
    }

    var weeklyUsedPercent: Double? {
        weeklyWindow?.usedPercent
    }

    var weeklyResetAt: Date? {
        weeklyWindow?.resetAt
    }

    var weeklyWindowSeconds: Int? {
        weeklyWindow?.windowDurationSeconds
    }

    var remainingPercent: Double {
        primaryWindow?.remainingPercent ?? max(0, 100 - usedPercent)
    }

    var weeklyRemainingPercent: Double? {
        weeklyWindow?.remainingPercent
    }

    var hasWeeklyWindow: Bool {
        weeklyWindow != nil
    }

    var isWeeklyPrimary: Bool {
        primaryWindow?.kind == .weekly
    }

    var isLimitReached: Bool {
        if allowed == false { return true }
        if limitReached == true { return true }
        if primaryWindow?.isLimitReached == true { return true }
        if secondaryWindow?.isLimitReached == true { return true }
        return false
    }

    var lowestRemainingPercent: Double { remainingPercent }

    var weeklyCycleIdentifier: String? {
        guard let weeklyResetAt else { return nil }
        return String(Int(weeklyResetAt.timeIntervalSince1970))
    }

    func weeklyResetIsOverdue(now: Date = Date(), grace: TimeInterval = 0) -> Bool {
        guard hasWeeklyWindow, let weeklyResetAt else { return false }
        return now.timeIntervalSince(weeklyResetAt) >= grace
    }

    var activatableWindow: UsageWindow? {
        if let weekly = weeklyWindow { return weekly }
        if let prim = primaryWindow, (prim.kind == .monthly || prim.kind == .weekly || prim.windowDurationSeconds >= AccountUsage.weeklyWindowThresholdSeconds) {
            return prim
        }
        if let sec = secondaryWindow, (sec.kind == .monthly || sec.kind == .weekly || sec.windowDurationSeconds >= AccountUsage.weeklyWindowThresholdSeconds) {
            return sec
        }
        return additionalWindows.first(where: { $0.kind == .monthly || $0.kind == .weekly || $0.windowDurationSeconds >= AccountUsage.weeklyWindowThresholdSeconds })
    }

    var hasActivatableWindow: Bool { activatableWindow != nil }

    var activatableResetAt: Date? {
        activatableWindow?.resetAt
    }

    var activatableRemainingPercent: Double? {
        activatableWindow?.remainingPercent
    }

    var activatableWindowSeconds: Int? {
        activatableWindow?.windowDurationSeconds
    }

    var activatableCycleIdentifier: String? {
        guard let resetAt = activatableResetAt else { return nil }
        return String(Int(resetAt.timeIntervalSince1970))
    }

    func activatableResetIsOverdue(now: Date = Date(), grace: TimeInterval = 0) -> Bool {
        guard let resetAt = activatableResetAt else { return false }
        return now.timeIntervalSince(resetAt) >= grace
    }

    static let placeholder = AccountUsage(
        primaryWindow: UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: 0),
        secondaryWindow: nil,
        additionalWindows: [],
        allowed: true,
        limitReached: false,
        creditsBalance: nil,
        hasCredits: false,
        isUnlimited: false,
        lastUpdated: Date(),
        error: nil,
        lastActivityAt: nil
    )
}

enum AccountStatus {
    case active
    case refreshing
    case stale
    case degraded
    case needsReauth
    case error(String)
}
