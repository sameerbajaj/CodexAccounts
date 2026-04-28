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
        case idToken, accountId, codexAuthJSON, lastTokenRefresh
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

struct AccountUsage: Equatable {
    static let weeklyWindowThresholdSeconds = 3 * 24 * 60 * 60

    /// Codex usage shown in the primary bar (short window when available, otherwise weekly)
    var usedPercent: Double
    var resetAt: Date?
    var primaryWindowSeconds: Int?
    var weeklyUsedPercent: Double?
    var weeklyResetAt: Date?
    var weeklyWindowSeconds: Int?
    var creditsBalance: Double?
    var hasCredits: Bool
    var isUnlimited: Bool
    var lastUpdated: Date
    var error: String?
    /// Tracks when usage % last changed (for "recently active" sort)
    var lastActivityAt: Date?

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }

    var weeklyRemainingPercent: Double? {
        guard let weeklyUsedPercent else { return nil }
        return max(0, 100 - weeklyUsedPercent)
    }

    var hasWeeklyWindow: Bool {
        weeklyUsedPercent != nil
    }

    var isWeeklyPrimary: Bool {
        guard hasWeeklyWindow else { return false }
        if let primaryWindowSeconds {
            return primaryWindowSeconds >= Self.weeklyWindowThresholdSeconds
        }
        if let weeklyResetAt {
            return resetAt == weeklyResetAt
        }
        return false
    }

    /// Alias kept so existing references compile
    var lowestRemainingPercent: Double { remainingPercent }

    var weeklyCycleIdentifier: String? {
        guard let weeklyResetAt else { return nil }
        return String(Int(weeklyResetAt.timeIntervalSince1970))
    }

    func weeklyResetIsOverdue(now: Date = Date(), grace: TimeInterval = 0) -> Bool {
        guard let weeklyResetAt else { return false }
        return now.timeIntervalSince(weeklyResetAt) >= grace
    }

    static let placeholder = AccountUsage(
        usedPercent: 0,
        resetAt: nil,
        primaryWindowSeconds: nil,
        weeklyUsedPercent: nil,
        weeklyResetAt: nil,
        weeklyWindowSeconds: nil,
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
