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

    init(
        email: String,
        planType: String,
        accessToken: String,
        refreshToken: String,
        idToken: String? = nil,
        accountId: String? = nil,
        lastTokenRefresh: Date? = nil
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
    var fiveHourUsedPercent: Double
    var fiveHourResetAt: Date?
    var weeklyUsedPercent: Double
    var weeklyResetAt: Date?
    var creditsBalance: Double?
    var hasCredits: Bool
    var isUnlimited: Bool
    var lastUpdated: Date
    var error: String?

    var fiveHourRemainingPercent: Double {
        max(0, 100 - fiveHourUsedPercent)
    }

    var weeklyRemainingPercent: Double {
        max(0, 100 - weeklyUsedPercent)
    }

    var lowestRemainingPercent: Double {
        min(fiveHourRemainingPercent, weeklyRemainingPercent)
    }

    static let placeholder = AccountUsage(
        fiveHourUsedPercent: 0,
        fiveHourResetAt: nil,
        weeklyUsedPercent: 0,
        weeklyResetAt: nil,
        creditsBalance: nil,
        hasCredits: false,
        isUnlimited: false,
        lastUpdated: Date(),
        error: nil
    )
}

enum AccountStatus {
    case active
    case refreshing
    case needsReauth
    case error(String)
}
