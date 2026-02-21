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
    init(from response: CodexUsageResponse) {
        let primary = response.rateLimit?.primaryWindow
        let secondary = response.rateLimit?.secondaryWindow

        self.fiveHourUsedPercent = Double(primary?.usedPercent ?? 0)
        self.fiveHourResetAt = primary.map { Date(timeIntervalSince1970: TimeInterval($0.resetAt)) }
        self.weeklyUsedPercent = Double(secondary?.usedPercent ?? 0)
        self.weeklyResetAt = secondary.map { Date(timeIntervalSince1970: TimeInterval($0.resetAt)) }
        self.creditsBalance = response.credits?.balance
        self.hasCredits = response.credits?.hasCredits ?? false
        self.isUnlimited = response.credits?.unlimited ?? false
        self.lastUpdated = Date()
        self.error = nil
    }
}
