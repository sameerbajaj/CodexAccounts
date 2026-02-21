//
//  CodexAccount.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

struct CodexAccount: Identifiable, Codable, Hashable {
    let id: String
    var email: String
    var planType: String
    var accessToken: String
    var refreshToken: String
    var idToken: String?
    var accountId: String?
    var lastTokenRefresh: Date?
    let addedAt: Date
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, planType, accessToken, refreshToken
        case idToken, accountId, lastTokenRefresh, addedAt, isPinned
    }

    init(
        email: String,
        planType: String,
        accessToken: String,
        refreshToken: String,
        idToken: String? = nil,
        accountId: String? = nil,
        lastTokenRefresh: Date? = nil,
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
        self.addedAt = Date()
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
}

struct AccountUsage: Equatable {
    /// Codex usage (primary rate-limit window) — the only bar we show
    var usedPercent: Double
    var resetAt: Date?
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

    /// Alias kept so existing references compile
    var lowestRemainingPercent: Double { remainingPercent }

    static let placeholder = AccountUsage(
        usedPercent: 0,
        resetAt: nil,
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
    case needsReauth
    case error(String)
}
