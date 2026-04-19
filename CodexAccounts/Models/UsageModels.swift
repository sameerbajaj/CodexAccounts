//
//  UsageModels.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

// MARK: - Usage API Response

struct CodexUsageResponse: Decodable {
    let planType: String?
    let rateLimit: RateLimitDetails?
    let credits: CreditDetails?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
    }

    struct RateLimitDetails: Decodable {
        let primaryWindow: WindowSnapshot?
        let secondaryWindow: WindowSnapshot?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct WindowSnapshot: Decodable {
        let usedPercent: Int
        let resetAt: Int
        let limitWindowSeconds: Int

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }
    }

    struct CreditDetails: Decodable {
        let hasCredits: Bool
        let unlimited: Bool
        let balance: Double?

        enum CodingKeys: String, CodingKey {
            case hasCredits = "has_credits"
            case unlimited
            case balance
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hasCredits = (try? container.decode(Bool.self, forKey: .hasCredits)) ?? false
            self.unlimited = (try? container.decode(Bool.self, forKey: .unlimited)) ?? false
            if let b = try? container.decode(Double.self, forKey: .balance) {
                self.balance = b
            } else if let s = try? container.decode(String.self, forKey: .balance),
                      let v = Double(s)
            {
                self.balance = v
            } else {
                self.balance = nil
            }
        }
    }
}

// MARK: - Token Refresh Response

struct TokenRefreshResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

// MARK: - Auth File

struct AuthFileContents: Decodable {
    let authMode: String?
    let tokens: TokenSet?
    let lastRefresh: String?
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case tokens
        case lastRefresh = "last_refresh"
        case apiKey = "OPENAI_API_KEY"
    }

    struct TokenSet: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let idToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
            case accountId = "account_id"
        }
    }
}

// MARK: - Convenience

extension AccountUsage {
    init(from response: CodexUsageResponse, previous: AccountUsage? = nil) {
        struct ParsedWindow {
            let usedPercent: Double
            let resetAt: Date
            let limitWindowSeconds: Int
        }

        let snapshots = [
            response.rateLimit?.primaryWindow,
            response.rateLimit?.secondaryWindow,
        ]
        .compactMap { $0 }

        let windows = snapshots.map { snapshot in
            ParsedWindow(
                usedPercent: Double(snapshot.usedPercent),
                resetAt: Date(timeIntervalSince1970: TimeInterval(snapshot.resetAt)),
                limitWindowSeconds: max(0, snapshot.limitWindowSeconds)
            )
        }

        let sortedByDuration = windows.sorted { $0.limitWindowSeconds < $1.limitWindowSeconds }
        let shortWindow: ParsedWindow?
        let weeklyWindow: ParsedWindow?

        if sortedByDuration.count >= 2 {
            let shortest = sortedByDuration.first
            let longest = sortedByDuration.last
            if let longest, longest.limitWindowSeconds >= AccountUsage.weeklyWindowThresholdSeconds {
                if let shortest, shortest.limitWindowSeconds < AccountUsage.weeklyWindowThresholdSeconds {
                    shortWindow = shortest
                } else {
                    shortWindow = nil
                }
                weeklyWindow = longest
            } else {
                shortWindow = shortest
                weeklyWindow = nil
            }
        } else if let onlyWindow = sortedByDuration.first {
            if onlyWindow.limitWindowSeconds >= AccountUsage.weeklyWindowThresholdSeconds {
                shortWindow = nil
                weeklyWindow = onlyWindow
            } else {
                shortWindow = onlyWindow
                weeklyWindow = nil
            }
        } else {
            shortWindow = nil
            weeklyWindow = nil
        }

        let primaryDisplayWindow = shortWindow ?? weeklyWindow

        self.usedPercent = primaryDisplayWindow?.usedPercent ?? 0
        self.resetAt = primaryDisplayWindow?.resetAt
        self.primaryWindowSeconds = primaryDisplayWindow?.limitWindowSeconds
        self.weeklyUsedPercent = weeklyWindow?.usedPercent
        self.weeklyResetAt = weeklyWindow?.resetAt
        self.weeklyWindowSeconds = weeklyWindow?.limitWindowSeconds
        self.creditsBalance = response.credits?.balance
        self.hasCredits = response.credits?.hasCredits ?? false
        self.isUnlimited = response.credits?.unlimited ?? false
        self.lastUpdated = Date()
        self.error = nil

        // Track activity: if used% changed from previous, mark now as last activity
        if let prev = previous, prev.usedPercent != self.usedPercent {
            self.lastActivityAt = Date()
        } else {
            self.lastActivityAt = previous?.lastActivityAt
        }
    }
}
