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

struct CodexAccount: Identifiable, Codable, Hashable {
    let id: String
    var email: String
    var planType: String
    var accessToken: String
    var refreshToken: String
    var idToken: String?
    var accountId: String?
    var lastTokenRefresh: Date?
    var lastSuccessfulUsageAt: Date?
    var lastSuccessfulTokenRefreshAt: Date?
    var lastRefreshAttemptAt: Date?
    var lastRefreshFailureAt: Date?
    var consecutiveRefreshFailures: Int
    var authState: AuthState
    let addedAt: Date
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, planType, accessToken, refreshToken
        case idToken, accountId, lastTokenRefresh
        case lastSuccessfulUsageAt, lastSuccessfulTokenRefreshAt
        case lastRefreshAttemptAt, lastRefreshFailureAt
        case consecutiveRefreshFailures, authState
        case addedAt, isPinned
    }

    init(
        email: String,
        planType: String,
        accessToken: String,
        refreshToken: String,
        idToken: String? = nil,
        accountId: String? = nil,
        lastTokenRefresh: Date? = nil,
        lastSuccessfulUsageAt: Date? = nil,
        lastSuccessfulTokenRefreshAt: Date? = nil,
        lastRefreshAttemptAt: Date? = nil,
        lastRefreshFailureAt: Date? = nil,
        consecutiveRefreshFailures: Int = 0,
        authState: AuthState = .healthy,
        addedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = email.lowercased()
        self.email = email
        self.planType = planType
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountId = accountId
        self.lastTokenRefresh = lastTokenRefresh
        self.lastSuccessfulUsageAt = lastSuccessfulUsageAt
        self.lastSuccessfulTokenRefreshAt = lastSuccessfulTokenRefreshAt ?? lastTokenRefresh
        self.lastRefreshAttemptAt = lastRefreshAttemptAt
        self.lastRefreshFailureAt = lastRefreshFailureAt
        self.consecutiveRefreshFailures = consecutiveRefreshFailures
        self.authState = authState
        self.addedAt = addedAt
        self.isPinned = isPinned
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
        lastTokenRefresh = try c.decodeIfPresent(Date.self, forKey: .lastTokenRefresh)
        lastSuccessfulUsageAt = try c.decodeIfPresent(Date.self, forKey: .lastSuccessfulUsageAt)
        lastSuccessfulTokenRefreshAt = try c.decodeIfPresent(Date.self, forKey: .lastSuccessfulTokenRefreshAt) ?? lastTokenRefresh
        lastRefreshAttemptAt = try c.decodeIfPresent(Date.self, forKey: .lastRefreshAttemptAt)
        lastRefreshFailureAt = try c.decodeIfPresent(Date.self, forKey: .lastRefreshFailureAt)
        consecutiveRefreshFailures = (try? c.decode(Int.self, forKey: .consecutiveRefreshFailures)) ?? 0
        authState = (try? c.decode(AuthState.self, forKey: .authState)) ?? .healthy
        addedAt = try c.decode(Date.self, forKey: .addedAt)
        isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
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
